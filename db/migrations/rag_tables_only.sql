-- RAG tables + functions only — no data seeding
-- Run before source tables are populated

create table if not exists document_embeddings (
  id              uuid primary key default uuid_generate_v4(),
  doc_type        text not null,
  source_id       uuid not null,
  supplier_id     uuid,  -- no FK constraint — avoids issues during seeding order
  chunk_index     int  not null default 0,
  chunk_text      text not null,
  embedding       text,
  meta_title      text,
  meta_category   text,
  meta_status     text,
  meta_tags       text[],
  created_at      timestamptz default now(),
  indexed_at      timestamptz default now()
);

create index if not exists idx_doc_embeddings_doc_type   on document_embeddings(doc_type);
create index if not exists idx_doc_embeddings_supplier   on document_embeddings(supplier_id);
create index if not exists idx_doc_embeddings_source     on document_embeddings(source_id);
create index if not exists idx_doc_embeddings_fts
  on document_embeddings
  using gin(to_tsvector('english', chunk_text || ' ' || coalesce(meta_title,'') || ' ' || coalesce(meta_category,'')));

create table if not exists rag_policies (
  id          uuid primary key default uuid_generate_v4(),
  title       text not null,
  category    text not null,
  content     text not null,
  version     text not null default '1.0',
  effective   date not null default current_date,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

create table if not exists rag_search_log (
  id          uuid primary key default uuid_generate_v4(),
  query_text  text not null,
  doc_type    text,
  result_ids  uuid[],
  user_email  text,
  clicked_id  uuid,
  created_at  timestamptz default now()
);

create or replace function search_documents_text(
  query_text      text,
  filter_doc_type text default null,
  filter_supplier uuid default null,
  result_limit    int  default 10
)
returns table (
  id           uuid,
  doc_type     text,
  source_id    uuid,
  supplier_id  uuid,
  chunk_text   text,
  meta_title   text,
  meta_category text,
  meta_status  text,
  meta_tags    text[],
  rank         float
)
language sql stable
as $$
  select
    de.id,
    de.doc_type,
    de.source_id,
    de.supplier_id,
    de.chunk_text,
    de.meta_title,
    de.meta_category,
    de.meta_status,
    de.meta_tags,
    ts_rank(
      to_tsvector('english', de.chunk_text || ' ' || coalesce(de.meta_title,'') || ' ' || coalesce(de.meta_category,'')),
      plainto_tsquery('english', query_text)
    )::float as rank
  from document_embeddings de
  where
    (filter_doc_type is null or de.doc_type = filter_doc_type)
    and (filter_supplier is null or de.supplier_id = filter_supplier)
    and to_tsvector('english', de.chunk_text || ' ' || coalesce(de.meta_title,'') || ' ' || coalesce(de.meta_category,''))
        @@ plainto_tsquery('english', query_text)
  order by rank desc
  limit result_limit;
$$;

grant select, insert, update on document_embeddings to truespend;
grant select on rag_policies to truespend;
grant select, insert, update on rag_search_log to truespend;
grant execute on function search_documents_text to truespend;
