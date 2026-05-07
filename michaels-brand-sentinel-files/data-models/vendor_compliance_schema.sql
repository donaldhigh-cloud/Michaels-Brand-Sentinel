-- vendor_compliance_schema.sql
-- BigQuery DDL plus seed data for the Michaels Brand Integrity Sentinel prototype.
-- Run this in the BigQuery console (project: ieco-495312) before deploying
-- the detect-vendor-risk Cloud Function.

CREATE SCHEMA IF NOT EXISTS `ieco-495312.ieco_michaels_brand_sentinel`
OPTIONS (
  description = "Prototype dataset for the Michaels Brand Integrity Sentinel agent",
  location = "US"
);

CREATE TABLE IF NOT EXISTS `ieco-495312.ieco_michaels_brand_sentinel.vendor_compliance_log` (
  vendor_id              STRING NOT NULL,
  vendor_name            STRING NOT NULL,
  region                 STRING NOT NULL,
  product_category       STRING NOT NULL,
  week_ending            DATE   NOT NULL,
  shipments_count        INT64  NOT NULL,
  defect_rate_pct        FLOAT64 NOT NULL,
  on_time_delivery_pct   FLOAT64 NOT NULL,
  return_rate_pct        FLOAT64 NOT NULL,
  vendor_code_compliant  BOOL   NOT NULL
)
OPTIONS (
  description = "Weekly vendor compliance and quality metrics. One row per vendor per week. Replace with real production feed before launch."
);

-- Seed data: 7 vendors x 12 weeks ending 2026-04-25 through 2026-02-07.
-- Three vendors have planted patterns:
--   SUZHOU-TX  : China textile vendor, defect rate spikes in last 2 weeks (counterfeit/quality slip)
--   MUMBAI-CR  : India crafts vendor, on-time delivery erodes steadily (logistics degradation)
--   VERACRUZ-AR: Mexico artisan vendor, healthy throughout (control / no false-positive)
-- The other four vendors are unremarkable filler.

INSERT INTO `ieco-495312.ieco_michaels_brand_sentinel.vendor_compliance_log`
  (vendor_id, vendor_name, region, product_category, week_ending,
   shipments_count, defect_rate_pct, on_time_delivery_pct, return_rate_pct, vendor_code_compliant)
VALUES
  -- ========== SUZHOU-TX (China) -- spikes in last 2 weeks ==========
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-02-07', 18, 1.9, 96.1, 1.4, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-02-14', 21, 2.1, 95.4, 1.2, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-02-21', 19, 1.8, 96.8, 1.5, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-02-28', 22, 2.0, 95.9, 1.3, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-03-07', 20, 2.2, 96.2, 1.6, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-03-14', 23, 1.7, 95.7, 1.1, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-03-21', 21, 2.0, 96.0, 1.4, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-03-28', 19, 2.1, 95.5, 1.3, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-04-04', 22, 1.9, 96.3, 1.5, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-04-11', 20, 2.2, 95.8, 1.4, TRUE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-04-18', 18, 8.4, 94.1, 4.7, FALSE),
  ('SUZHOU-TX','Suzhou Textile Group','East Asia','Textiles', DATE '2026-04-25', 17, 9.1, 93.8, 5.2, FALSE),

  -- ========== MUMBAI-CR (India) -- on-time erodes from 95% to 71% over 8 weeks ==========
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-02-07', 14, 2.4, 95.8, 1.7, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-02-14', 15, 2.6, 95.1, 1.8, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-02-21', 13, 2.5, 95.4, 1.6, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-02-28', 14, 2.7, 94.6, 1.9, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-03-07', 16, 2.5, 91.2, 1.7, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-03-14', 15, 2.8, 87.9, 1.8, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-03-21', 14, 2.6, 84.4, 1.6, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-03-28', 13, 2.7, 80.7, 1.9, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-04-04', 14, 2.5, 77.3, 1.7, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-04-11', 12, 2.8, 74.1, 1.8, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-04-18', 13, 2.6, 72.4, 1.6, TRUE),
  ('MUMBAI-CR','Mumbai Crafts Co.','South Asia','Beads & Findings', DATE '2026-04-25', 12, 2.7, 71.0, 1.9, TRUE),

  -- ========== VERACRUZ-AR (Mexico) -- control, healthy throughout ==========
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-02-07', 11, 1.5, 97.2, 1.1, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-02-14', 12, 1.4, 96.8, 1.0, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-02-21', 10, 1.6, 97.5, 1.2, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-02-28', 11, 1.3, 97.0, 0.9, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-03-07', 12, 1.7, 96.5, 1.3, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-03-14', 11, 1.5, 97.1, 1.1, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-03-21', 10, 1.4, 97.3, 1.0, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-03-28', 12, 1.6, 96.9, 1.2, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-04-04', 11, 1.5, 97.0, 1.1, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-04-11', 12, 1.3, 97.4, 0.9, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-04-18', 11, 1.5, 97.2, 1.1, TRUE),
  ('VERACRUZ-AR','Veracruz Artisans','Latin America','Floral & Naturals', DATE '2026-04-25', 12, 1.6, 96.8, 1.2, TRUE),

  -- ========== Filler vendor 1: DHAKA-TH (Bangladesh) -- healthy South Asia control ==========
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-02-07', 16, 2.1, 94.5, 1.5, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-02-14', 17, 2.3, 94.8, 1.6, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-02-21', 15, 2.0, 95.1, 1.4, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-02-28', 16, 2.2, 94.7, 1.5, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-03-07', 18, 2.1, 94.9, 1.6, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-03-14', 17, 2.4, 94.3, 1.7, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-03-21', 16, 2.2, 95.0, 1.5, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-03-28', 17, 2.0, 94.6, 1.4, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-04-04', 16, 2.3, 94.8, 1.6, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-04-11', 18, 2.1, 95.2, 1.5, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-04-18', 17, 2.2, 94.7, 1.6, TRUE),
  ('DHAKA-TH','Dhaka Threads Ltd.','South Asia','Yarn & Fiber', DATE '2026-04-25', 16, 2.0, 95.0, 1.4, TRUE),

  -- ========== Filler vendor 2: KARACHI-WV (Pakistan) -- healthy South Asia control ==========
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-02-07', 13, 2.5, 93.2, 1.8, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-02-14', 14, 2.7, 93.6, 1.9, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-02-21', 12, 2.4, 93.9, 1.7, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-02-28', 13, 2.6, 93.4, 1.8, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-03-07', 14, 2.5, 93.7, 1.9, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-03-14', 13, 2.8, 93.1, 1.7, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-03-21', 12, 2.6, 93.5, 1.8, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-03-28', 14, 2.4, 93.8, 1.6, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-04-04', 13, 2.7, 93.3, 1.9, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-04-11', 14, 2.5, 93.6, 1.7, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-04-18', 13, 2.6, 93.4, 1.8, TRUE),
  ('KARACHI-WV','Karachi Weavers','South Asia','Textiles', DATE '2026-04-25', 12, 2.4, 93.9, 1.7, TRUE),

  -- ========== Filler vendor 3: GUANGZHOU-PL (China) -- healthy East Asia control ==========
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-02-07', 25, 3.1, 92.4, 2.3, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-02-14', 26, 3.3, 92.7, 2.4, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-02-21', 24, 3.0, 92.1, 2.2, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-02-28', 25, 3.2, 92.5, 2.3, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-03-07', 27, 3.1, 92.8, 2.4, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-03-14', 26, 3.4, 92.2, 2.5, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-03-21', 25, 3.2, 92.6, 2.3, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-03-28', 26, 3.0, 92.4, 2.2, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-04-04', 25, 3.3, 92.7, 2.4, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-04-11', 27, 3.1, 92.9, 2.3, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-04-18', 26, 3.2, 92.5, 2.4, TRUE),
  ('GUANGZHOU-PL','Guangzhou Plastics Mfg.','East Asia','Plastics & Resin', DATE '2026-04-25', 25, 3.0, 92.8, 2.2, TRUE),

  -- ========== Filler vendor 4: PORTO-WD (Portugal) -- healthy Europe control ==========
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-02-07', 9, 1.8, 98.1, 0.8, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-02-14', 10, 1.9, 97.9, 0.9, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-02-21', 8, 1.7, 98.3, 0.7, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-02-28', 9, 1.8, 98.0, 0.8, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-03-07', 10, 1.6, 98.2, 0.7, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-03-14', 9, 1.9, 97.8, 0.9, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-03-21', 8, 1.7, 98.1, 0.8, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-03-28', 9, 1.8, 98.3, 0.7, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-04-04', 10, 1.6, 97.9, 0.9, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-04-11', 9, 1.9, 98.2, 0.8, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-04-18', 8, 1.7, 98.0, 0.7, TRUE),
  ('PORTO-WD','Porto Wood Crafts','Europe','Wood & Frames', DATE '2026-04-25', 9, 1.8, 98.1, 0.8, TRUE);
