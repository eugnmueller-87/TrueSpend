-- TrueSpend Seed — Compliance Checks for Expanded Suppliers
-- Columns: id, supplier_id, check_type, status, score, full_report, checked_at
-- Schema: compliance_checks(id, supplier_id, check_type, status, score, passed, findings[], blockers[], full_report, checked_at)

-- Live schema: id, supplier_id, check_type, status, score (integer), notes (text), created_at
insert into compliance_checks (
  id, supplier_id, check_type, status, score, notes, created_at
) values

-- ============================================================
-- HP INC. — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000001', 'lawyer',      'green', 95,  'NDA and DPA signed. Contract terms standard. No unusual liability clauses. IP ownership clear.',                                                                                                                   now() - interval '21 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000001', 'gdpr',        'green', 92,  'DPA signed. EU data residency confirmed Frankfurt. ISO 27001 certified. EU-US DPF participation verified. Sub-processor list current.',                                                                           now() - interval '21 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000001', 'infosec',     'green', 88,  'ISO 27001:2022 certified. HP Sure Click endpoint security. Vulnerability disclosure programme active. No material CVEs outstanding.',                                                                              now() - interval '21 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000001', 'lksg',        'green', 90,  'LkSG declaration signed. HP Global Citizenship Report 2024 reviewed. No child/forced labour findings. Conflict minerals policy in place.',                                                                        now() - interval '21 months'),

-- ============================================================
-- CISCO SYSTEMS — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000002', 'lawyer',      'green', 94,  'Bilateral NDA signed. Cisco EA contract terms reviewed. Exit clause reasonable. No penalty clauses.',                                                                                                             now() - interval '19 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000002', 'gdpr',        'green', 91,  'DPA signed. Cisco Cloud Services EU residency confirmed. ISO 27001. EU-US DPF verified. Smart Licensing telemetry data minimised.',                                                                               now() - interval '19 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000002', 'infosec',     'green', 96,  'ISO 27001, SOC 2 Type II, CSA STAR. PSIRT process mature. Network equipment security features verified. No known critical CVEs on deployed SKUs.',                                                                now() - interval '19 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000002', 'lksg',        'green', 88,  'Cisco ESG Report reviewed. Supplier code of conduct signed. Conflict minerals reporting compliant. No sanctions exposure.',                                                                                       now() - interval '19 months'),

-- ============================================================
-- SAMSUNG — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000003', 'lawyer',      'green', 91,  'NDA signed. Samsung Enterprise agreement terms standard. MDM integration clauses reviewed and acceptable.',                                                                                                       now() - interval '16 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000003', 'gdpr',        'green', 89,  'DPA signed. Knox MDM EU data residency confirmed. No Korea transfer without SCCs. ISO 27001 certified. Data minimisation confirmed.',                                                                              now() - interval '16 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000003', 'infosec',     'green', 87,  'Samsung Knox certified. Common Criteria EAL2+ for Knox platform. MDM security controls reviewed. Patching cadence: monthly.',                                                                                    now() - interval '16 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000003', 'lksg',        'green', 86,  'Samsung Sustainability Report 2024. COC signed. No major labour findings in Tier 1 factories. Conflict minerals: RCI compliant.',                                                                                 now() - interval '16 months'),

-- ============================================================
-- FUJITSU — amber: DPA expiring, restructuring risk
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000004', 'lawyer',      'amber', 72,  'NDA/DPA signed but expiring 2026-06-30. Fujitsu corporate restructuring in progress. Legal entity may change. Contract novation clause must be reviewed before renewal.',                                         now() - interval '23 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000004', 'gdpr',        'amber', 68,  'DPA expiring June 2026. EU processing confirmed but new legal entity after restructuring must re-sign DPA. Data residency commitment must be reconfirmed with new Fujitsu entity.',                                 now() - interval '23 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000004', 'infosec',     'green', 82,  'ISO 27001 certified. Server hardware security tested. PSIRT process active. No critical CVEs on PRIMERGY SKUs.',                                                                                                  now() - interval '23 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000004', 'lksg',        'green', 84,  'Fujitsu Responsible Business Report reviewed. Supply chain due diligence documented. No LkSG blockers.',                                                                                                          now() - interval '23 months'),

-- ============================================================
-- LOGITECH — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000005', 'lawyer',      'green', 90,  'Standard vendor terms. Volume pricing agreement reviewed. No unusual clauses.',                                                                                                                                   now() - interval '13 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000005', 'gdpr',        'green', 88,  'DPA on file. Logitech software data processing EU-compliant. No sensitive data categories processed.',                                                                                                            now() - interval '13 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000005', 'infosec',     'green', 85,  'ISO 27001 certified. Peripheral firmware security reviewed. No known CVEs on enterprise SKUs.',                                                                                                                   now() - interval '13 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000005', 'lksg',        'green', 86,  'Logitech Impact Report reviewed. No child labour findings. COC signed by Logitech regional team.',                                                                                                                now() - interval '13 months'),

-- ============================================================
-- ORACLE CLOUD — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000009', 'lawyer',      'green', 93,  'Oracle standard cloud contract reviewed. Exit rights adequate. Price increase cap negotiated at 5% annual. IP protection clauses reviewed.',                                                                      now() - interval '16 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000009', 'gdpr',        'green', 94,  'DPA signed. OCI EU region Frankfurt and Amsterdam confirmed. ISO 27001, SOC 2 Type II, CSA STAR Level 2. DPIA completed. EU-US DPF verified.',                                                                    now() - interval '16 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000009', 'infosec',     'green', 95,  'ISO 27001, FedRAMP High, DoD IL5. OCI security architecture reviewed. Network isolation confirmed for TrueSpend tenant. Penetration test report 2025 reviewed.',                                                  now() - interval '16 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000009', 'lksg',        'green', 89,  'Oracle ESG Report 2024. No LkSG blockers. Oracle Supplier Code of Ethics signed. No sanctions exposure.',                                                                                                        now() - interval '16 months'),

-- ============================================================
-- IBM CLOUD — amber: DPA expiring, migration risk
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000010', 'lawyer',      'amber', 74,  'NDA/DPA expiring 2026-07-31. IBM cloud contract scope change requires legal review. Migration delay clause being negotiated.',                                                                                     now() - interval '22 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000010', 'gdpr',        'amber', 71,  'DPA expires July 2026. EU region confirmed. However migration to IBM Hybrid Cloud may introduce new processing locations. Updated DPA required before any scope change executes.',                                  now() - interval '22 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000010', 'infosec',     'green', 87,  'IBM SOC 2 Type II, ISO 27001. zSystems inherently air-gapped. Encryption at rest and in transit confirmed.',                                                                                                      now() - interval '22 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000010', 'lksg',        'green', 88,  'IBM ESG Report reviewed. Supplier diversity programme noted. No LkSG blockers.',                                                                                                                                  now() - interval '22 months'),

-- ============================================================
-- SERVICENOW — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000015', 'lawyer',      'green', 92,  'NDA/DPA signed. ServiceNow SaaS agreement reviewed. Exit portability clause confirmed. No vendor lock-in terms.',                                                                                                 now() - interval '21 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000015', 'gdpr',        'green', 93,  'DPA signed. EU data residency Amsterdam and Dublin. ISO 27001, SOC 2 Type II, FedRAMP Moderate. Sub-processor list maintained. 2021 SCCs in place.',                                                              now() - interval '21 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000015', 'infosec',     'green', 91,  'ISO 27001, SOC 2 Type II, CSA STAR. Now Platform security posture reviewed. SSO and MFA enforced. Custom role separation confirmed.',                                                                             now() - interval '21 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000015', 'lksg',        'green', 87,  'ServiceNow ESG Report. No LkSG blockers. Supplier code of conduct signed.',                                                                                                                                      now() - interval '21 months'),

-- ============================================================
-- HUBSPOT — amber: DPA expiring
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000016', 'lawyer',      'amber', 76,  'DPA expiring July 2026. Renewal negotiations in progress. New HubSpot AI features require updated DPA addendum covering AI data usage.',                                                                           now() - interval '10 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000016', 'gdpr',        'amber', 73,  'DPA expiring. HubSpot AI features may process customer data for model improvement. Opt-out confirmed but needs DPA clause. EU residency maintained.',                                                               now() - interval '10 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000016', 'infosec',     'green', 86,  'ISO 27001, SOC 2 Type II. SSO enforced. HubSpot security portal reviewed. No critical CVEs outstanding.',                                                                                                        now() - interval '10 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000016', 'lksg',        'green', 88,  'HubSpot Culture Code reviewed. No LkSG concerns. COC signed.',                                                                                                                                                   now() - interval '10 months'),

-- ============================================================
-- ATLASSIAN — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000017', 'lawyer',      'green', 91,  'DPA signed. Cloud agreement reviewed. Data portability via export APIs confirmed. Australia to EU SCCs current.',                                                                                                 now() - interval '7 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000017', 'gdpr',        'green', 90,  'DPA signed. EU residency elected Ireland and Germany. 2021 SCCs for Atlassian Corp Pty Ltd Australia. Sub-processor list current. Atlassian Guard security controls verified.',                                    now() - interval '7 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000017', 'infosec',     'green', 89,  'ISO 27001, SOC 2 Type II. Atlassian Access SSO and MFA enforced. IP allowlisting configured. No critical CVEs.',                                                                                                  now() - interval '7 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000017', 'lksg',        'green', 86,  'Atlassian ESG Report 2024. No LkSG blockers. COC signed.',                                                                                                                                                       now() - interval '7 months'),

-- ============================================================
-- MONDAY.COM — amber: GDPR transfer unresolved
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000026', 'lawyer',      'amber', 68,  'Contract cannot auto-renew until DPA resolved. Monday.com Israel entity must sign 2021 SCCs. Legal review ongoing.',                                                                                              now() - interval '45 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000026', 'gdpr',        'amber', 60,  'BLOCKING: Israel not on EU adequacy list. SCCs required for Monday.com Ltd Israel. EU data residency AWS eu-west-1 confirmed but legal transfer mechanism incomplete. Cannot approve new data flows until resolved.', now() - interval '45 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000026', 'infosec',     'green', 84,  'ISO 27001, SOC 2 Type II. SSO enforced. Data encryption at rest and in transit. No known vulnerabilities.',                                                                                                      now() - interval '45 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000026', 'lksg',        'green', 87,  'Monday.com ESG Report. Israeli company. No LkSG Tier 1 concerns. COC signed.',                                                                                                                                   now() - interval '45 days'),

-- ============================================================
-- FIGMA — amber: entity change post-Adobe acquisition
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000023', 'lawyer',      'amber', 70,  'Adobe acquisition changes legal entity. Existing DPA with Figma Inc Delaware may not cover data processed under Adobe integration. New DPA with correct entity required.',                                         now() - interval '30 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000023', 'gdpr',        'amber', 67,  'DPA entity review required. Figma to Adobe data sharing during integration period creates new processing activities. Updated DPIA and DPA needed before next renewal.',                                             now() - interval '30 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000023', 'infosec',     'green', 85,  'Figma ISO 27001, SOC 2 Type II. SSO enforced. No critical security incidents.',                                                                                                                                   now() - interval '30 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000023', 'lksg',        'green', 88,  'Figma/Adobe ESG commitment noted. No LkSG concerns.',                                                                                                                                                             now() - interval '30 days'),

-- ============================================================
-- CROWDSTRIKE — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000031', 'lawyer',      'green', 92,  'DPA signed. Contract reviewed. Exit portability: telemetry data export confirmed. No unusual IP clauses.',                                                                                                        now() - interval '5 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000031', 'gdpr',        'green', 93,  'DPA signed. EU GovCloud region. ISO 27001, SOC 2 Type II, FedRAMP High. EU-US DPF and 2021 SCCs. Threat intelligence shared in anonymised form only.',                                                            now() - interval '5 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000031', 'infosec',     'green', 97,  'CrowdStrike is a security vendor with mature security posture. FedRAMP High. Zero trust architecture. July 2024 incident post-mortem reviewed and remediation verified.',                                          now() - interval '5 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000031', 'lksg',        'green', 89,  'CrowdStrike ESG Report 2024. No LkSG blockers. COC signed. No sanctions exposure.',                                                                                                                              now() - interval '5 months'),

-- ============================================================
-- OKTA — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000032', 'lawyer',      'green', 91,  'DPA signed. Okta SaaS agreement reviewed. Data export available via SCIM/API. Liability cap appropriate.',                                                                                                       now() - interval '15 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000032', 'gdpr',        'green', 94,  'DPA signed. EU cell eu.okta.com confirmed Ireland and Germany. ISO 27001, SOC 2 Type II. SCCs for Okta Inc US sub-processing. Data retention 90-day purge for logs.',                                              now() - interval '15 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000032', 'infosec',     'green', 95,  'ISO 27001, SOC 2 Type II, FedRAMP Moderate. Okta ThreatInsight enabled. Admin console IP restriction configured. Phishing-resistant MFA enforced.',                                                               now() - interval '15 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000032', 'lksg',        'green', 88,  'Okta ESG Report. No LkSG concerns. COC signed.',                                                                                                                                                                 now() - interval '15 months'),

-- ============================================================
-- INFOSYS — amber: LkSG declaration pending
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000042', 'lawyer',      'green', 87,  'NDA signed. BPO contract terms reviewed. IP ownership clear. Exit clause: 90-day transition support required.',                                                                                                   now() - interval '14 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000042', 'gdpr',        'green', 85,  'DPA signed. Hybrid onshore/offshore delivery with SCCs for India transfers. ISO 27001 certified. DPIA completed.',                                                                                                now() - interval '14 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000042', 'infosec',     'green', 88,  'ISO 27001, SOC 2 Type II. Infosys Secure Zone controls reviewed. Data segregation confirmed. Penetration test 2024 reviewed with no critical findings.',                                                           now() - interval '14 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000042', 'lksg',        'amber', 62,  'PENDING: LkSG supply chain declaration not yet signed. India delivery centres require audit confirmation. Formal LkSG declaration required by German law for suppliers over 5M EUR. Sent to Infosys awaiting signature.', now() - interval '14 months'),

-- ============================================================
-- WIPRO — amber: SOC 2 overdue + no DPA
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000043', 'lawyer',      'green', 82,  'Contract terms reviewed. Exit clause standard. IP protection adequate.',                                                                                                                                          now() - interval '8 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000043', 'gdpr',        'amber', 66,  'No DPA on file. Wipro processes some internal process data. DPA generation required before any data processing scope expansion.',                                                                                  now() - interval '8 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000043', 'infosec',     'amber', 60,  'ISSUE: SOC 2 Type II report overdue. Last report was 2023. Wipro has not provided updated 2024/2025 report despite requests. Cannot confirm security controls are current. Remediation required.',                 now() - interval '8 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000043', 'lksg',        'green', 80,  'Wipro ESG Report reviewed. No major LkSG blockers but audit scheduling behind.',                                                                                                                                  now() - interval '8 months'),

-- ============================================================
-- G4S — amber: LkSG certification pending
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000059', 'lawyer',      'green', 84,  'Security services contract reviewed. Insurance certificates current. No unusual liability limitations.',                                                                                                           now() - interval '6 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000059', 'gdpr',        'green', 85,  'Limited personal data processing CCTV logs only. GDPR notice to staff confirmed. Data retention 30 days for CCTV. DPA not required for this processing type.',                                                    now() - interval '6 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000059', 'infosec',     'green', 81,  'ISO 9001 certified. Access control systems ISO 27001 aligned. No IT systems access as physical security only.',                                                                                                   now() - interval '6 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000059', 'lksg',        'amber', 58,  'BLOCKING: LkSG declaration not signed. G4S must confirm German minimum wage compliance for all guards and no forced labour in supply chain. G4S has had labour practice controversies in UK. Contract extension blocked until signature.', now() - interval '6 months'),

-- ============================================================
-- ANTHROPIC — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000066', 'lawyer',      'green', 93,  'API usage agreement reviewed. No IP transfer. Prompt data not used for training under commercial agreement. Exit: immediate, no lock-in.',                                                                        now() - interval '5 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000066', 'gdpr',        'green', 91,  'DPA signed. Zero-retention policy for API prompts. EU-US DPF participation. 2021 SCCs. No persistent storage. DPIA completed for TrueSpend procAI use case.',                                                     now() - interval '5 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000066', 'infosec',     'green', 90,  'Anthropic Trust Portal reviewed. SOC 2 Type II in progress. API keys rotated quarterly. Rate limiting and abuse detection active. No known breaches.',                                                             now() - interval '5 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000066', 'lksg',        'green', 88,  'Anthropic responsible AI commitments reviewed. Acceptable use policy aligned with TrueSpend ethics framework. No LkSG concerns.',                                                                                  now() - interval '5 months'),

-- ============================================================
-- OPENAI — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000067', 'lawyer',      'green', 91,  'DPA and API agreement reviewed. Zero Data Retention elected. No IP claims on prompts. Exit: immediate.',                                                                                                          now() - interval '4 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000067', 'gdpr',        'green', 90,  'DPA signed. ZDR policy elected. 2021 SCCs. Microsoft Azure EU regions for inference. DPIA completed. Sub-processor list current.',                                                                                now() - interval '4 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000067', 'infosec',     'green', 89,  'OpenAI security programme reviewed. SOC 2 Type II. API key management per policy. Rate limiting active. Bug bounty programme active.',                                                                             now() - interval '4 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000067', 'lksg',        'green', 86,  'OpenAI responsible use commitments reviewed. No LkSG concerns. Acceptable use policy adequate.',                                                                                                                  now() - interval '4 months'),

-- ============================================================
-- COHERE — amber: EU residency and DPA pending
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000068', 'lawyer',      'amber', 70,  'No DPA signed. Contract review initiated but not complete. Cannot approve data processing until DPA executed.',                                                                                                   now() - interval '2 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000068', 'gdpr',        'amber', 58,  'PENDING: EU data residency option exists but not yet confirmed. Canada has no EU adequacy decision. 2021 SCCs required. DPA draft sent to Cohere legal with no response yet.',                                     now() - interval '2 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000068', 'infosec',     'green', 82,  'Cohere security controls reviewed via security questionnaire. SOC 2 Type II in progress. Acceptable posture for current usage tier.',                                                                              now() - interval '2 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000068', 'lksg',        'green', 86,  'No significant LkSG concerns for AI software company. AI ethics framework reviewed.',                                                                                                                             now() - interval '2 months'),

-- ============================================================
-- MISTRAL AI — all green (best GDPR posture)
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000069', 'lawyer',      'green', 92,  'DPA signed. French law. EU-native provider, no SCCs required. Exit immediate.',                                                                                                                                   now() - interval '3 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000069', 'gdpr',        'green', 96,  'DPA signed. EU-native France OVH. CNIL registered. No third-country transfers. Gold standard GDPR compliance posture. Intra-EU processing only. Data deleted post-session.',                                       now() - interval '3 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000069', 'infosec',     'green', 88,  'OVH ISO 27001 infrastructure. Mistral security questionnaire reviewed. No known CVEs. Penetration test scheduled Q3 2026.',                                                                                       now() - interval '3 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000069', 'lksg',        'green', 90,  'EU-native AI company. Mistral AI Act compliance roadmap reviewed ahead of competitors. No LkSG concerns.',                                                                                                       now() - interval '3 months'),

-- ============================================================
-- DELOITTE — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000036', 'lawyer',      'green', 94,  'NDA/DPA signed. Engagement letter reviewed. Independence requirements met. No conflicts of interest identified.',                                                                                                  now() - interval '20 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000036', 'gdpr',        'green', 93,  'DPA signed. EU processing only Frankfurt. ISO 27001. No third-country transfers. Data retention per HGB §257.',                                                                                                   now() - interval '20 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000036', 'infosec',     'green', 91,  'Deloitte ISO 27001 certified. Client data portal access-controlled. SOC 2 equivalent controls verified.',                                                                                                        now() - interval '20 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000036', 'lksg',        'green', 92,  'Deloitte Global Impact Report 2024. No LkSG concerns. Professional services exemption applies. Internal COC reviewed.',                                                                                           now() - interval '20 months'),

-- ============================================================
-- CAPGEMINI — all green
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000040', 'lawyer',      'green', 89,  'NDA/DPA signed. SOW reviewed. Milestone-based payments confirmed. Exit clause 60-day transition assistance. IP ownership of custom code: TrueSpend retains full ownership.',                                      now() - interval '19 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000040', 'gdpr',        'green', 91,  'DPA signed. Germany-only delivery confirmed. ISO 27001, BSI C5 audit completed. No offshore data transfer.',                                                                                                      now() - interval '19 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000040', 'infosec',     'green', 88,  'Capgemini ISO 27001, BSI C5 certified. Secure delivery environment reviewed. VPN and MFA for system access.',                                                                                                     now() - interval '19 months'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000040', 'lksg',        'green', 86,  'Capgemini SSBI Report reviewed. No LkSG blockers. Capgemini signed UN Global Compact. COC signed.',                                                                                                              now() - interval '19 months'),

-- ============================================================
-- CGI — amber: DPA scope amendment pending
-- ============================================================
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000083', 'lawyer',      'amber', 75,  'DPA amendment required for new HR data processing scope. Current contract does not cover expanded data categories. Legal review in progress.',                                                                     now() - interval '23 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000083', 'gdpr',        'amber', 70,  'Existing DPA does not cover HR data including employee performance and payroll inputs. Fresh DPIA required. Cannot expand scope until DPA amendment signed and DPIA approved.',                                     now() - interval '23 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000083', 'infosec',     'green', 87,  'CGI ISO 27001 certified. SOC 2 Type II. Managed services security reviewed. Patch management SLA confirmed.',                                                                                                    now() - interval '23 days'),
(gen_random_uuid(), 'f2000000-0000-0000-0000-000000000083', 'lksg',        'green', 86,  'CGI Sustainability Report reviewed. No LkSG blockers. COC signed.',                                                                                                                                              now() - interval '23 days')

on conflict do nothing;
