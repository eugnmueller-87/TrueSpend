-- TrueSpend Seed — 10 Branches with legal entity data
-- legal_name / street_address / city_zip / vat_number drive PO headers per branch.
-- po_prefix feeds the PO number sequence (PO-{PREFIX}-{YEAR}-{SEQ}).
-- po_email is the issuing address shown on the PO document.
-- Replace placeholder legal details with actual registered entity data before go-live.

insert into branches (
  id, name, region, country, currency,
  legal_name, street_address, city_zip, vat_number, po_email, po_prefix,
  annual_budget, budget_owner
) values
  (
    'b1000000-0000-0000-0000-000000000001',
    'Global HQ', 'GLOBAL_HQ', 'Germany', 'EUR',
    'TrueSpend GmbH',
    'Taunusanlage 12',
    '60325 Frankfurt am Main, Germany',
    'DE123456789',
    'procurement@truespend.com',
    'HQ',
    25000000.00, 'CFO Office'
  ),
  (
    'b1000000-0000-0000-0000-000000000002',
    'DACH Operations', 'DACH', 'Germany', 'EUR',
    'TrueSpend GmbH',
    'Maximilianstrasse 35',
    '80539 Muenchen, Germany',
    'DE123456789',
    'procurement.dach@truespend.com',
    'DACH',
    18000000.00, 'Regional VP DACH'
  ),
  (
    'b1000000-0000-0000-0000-000000000003',
    'UK & Ireland', 'UK_IE', 'UK', 'GBP',
    'TrueSpend Ltd',
    '1 Canada Square',
    'London E14 5AB, United Kingdom',
    'GB987654321',
    'procurement.uk@truespend.com',
    'UKIE',
    9500000.00, 'Country Director UK'
  ),
  (
    'b1000000-0000-0000-0000-000000000004',
    'Benelux', 'BENELUX', 'Netherlands', 'EUR',
    'TrueSpend B.V.',
    'Barbara Strozzilaan 201',
    '1083 HN Amsterdam, Netherlands',
    'NL123456789B01',
    'procurement.benelux@truespend.com',
    'BNL',
    7200000.00, 'Regional VP Benelux'
  ),
  (
    'b1000000-0000-0000-0000-000000000005',
    'France', 'FRANCE', 'France', 'EUR',
    'TrueSpend SAS',
    '1 Avenue des Champs-Elysees',
    '75008 Paris, France',
    'FR12345678901',
    'procurement.fr@truespend.com',
    'FR',
    8100000.00, 'Country Director France'
  ),
  (
    'b1000000-0000-0000-0000-000000000006',
    'Nordics', 'NORDICS', 'Sweden', 'SEK',
    'TrueSpend AB',
    'Birger Jarlsgatan 57A',
    '113 56 Stockholm, Sweden',
    'SE123456789001',
    'procurement.nordics@truespend.com',
    'NORD',
    6400000.00, 'Regional VP Nordics'
  ),
  (
    'b1000000-0000-0000-0000-000000000007',
    'Iberia', 'IBERIA', 'Spain', 'EUR',
    'TrueSpend S.L.',
    'Paseo de la Castellana 259',
    '28046 Madrid, Spain',
    'ESB12345678',
    'procurement.iberia@truespend.com',
    'IB',
    4800000.00, 'Country Director Spain'
  ),
  (
    'b1000000-0000-0000-0000-000000000008',
    'Italy', 'ITALY', 'Italy', 'EUR',
    'TrueSpend S.r.l.',
    'Via Monte Napoleone 8',
    '20121 Milano MI, Italy',
    'IT12345678901',
    'procurement.it@truespend.com',
    'IT',
    5300000.00, 'Country Director Italy'
  ),
  (
    'b1000000-0000-0000-0000-000000000009',
    'CEE', 'CEE', 'Poland', 'PLN',
    'TrueSpend Sp. z o.o.',
    'Al. Jerozolimskie 65/79',
    '00-697 Warszawa, Poland',
    'PL1234567890',
    'procurement.cee@truespend.com',
    'CEE',
    3900000.00, 'Regional VP CEE'
  ),
  (
    'b1000000-0000-0000-0000-000000000010',
    'Nordics East', 'NORDICS_EAST', 'Finland', 'EUR',
    'TrueSpend Oy',
    'Mannerheimintie 12',
    '00100 Helsinki, Finland',
    'FI12345678',
    'procurement.fi@truespend.com',
    'FI',
    3100000.00, 'Country Director Finland'
  )
on conflict (id) do update set
  legal_name     = excluded.legal_name,
  street_address = excluded.street_address,
  city_zip       = excluded.city_zip,
  vat_number     = excluded.vat_number,
  po_email       = excluded.po_email,
  po_prefix      = excluded.po_prefix;
