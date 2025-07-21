### **1. Using the Standard EXPOSURE Table (Recommended)**
For most external exposures (e.g., environmental, occupational, or exposures from claims data), the EXPOSURE table can be used with proper configuration:

```sql
INSERT INTO exposure (
    person_id,
    exposure_concept_id,
    exposure_start_date,
    exposure_end_date,
    exposure_type_concept_id,
    quantity,
    unit_concept_id,
    visit_occurrence_id,
    exposure_source_value
)
VALUES (
    12345,                              -- person_id
    4167217,                           -- Concept for 'air pollution' (OMOP standard concept)
    '2023-01-15',                      -- start date
    '2023-01-15',                      -- end date (same day for point exposure)
    32534,                             -- Type: 'Environmental exposure recorded in external database'
    NULL,                              -- quantity if available
    NULL,                              -- unit if available
    NULL,                              -- link to visit if applicable
    'EPA_AIR_QUALITY_ID_XYZ'           -- original source identifier
);
```

**Key Fields for External Exposures:**
- `exposure_type_concept_id`: Use OHDSI-defined concepts like:
  - `32534` (Environmental exposure recorded in external database)
  - `32535` (Occupational exposure recorded in external database)
  - `32536` (Exposure recorded in claims)
- `exposure_source_value`: Store the original exposure code from your external source.
- `visit_occurrence_id`: Link to an external encounter if applicable.

---

### **2. Extension Tables for Additional Metadata**
If your external exposures have rich metadata (e.g., geographic coordinates, device IDs), create a supplemental table:

```sql
CREATE TABLE exposure_extension (
    exposure_id INT PRIMARY KEY REFERENCES exposure(exposure_id),
    external_source VARCHAR(50),        -- e.g., 'EPA', 'Occupational_Survey'
    external_id VARCHAR(255),           -- original system's ID
    latitude FLOAT,                     -- for geospatial exposures
    longitude FLOAT,
    confidence_score FLOAT              -- data quality metric
);
```

---

### **3. Handling Specific External Exposure Types**

#### **A. Environmental Exposures (Air Pollution, Water Contaminants)**
- **Concepts**: Use SNOMED/OMOP concepts like:
  - `4167217` (Air pollution)
  - `4269896` (Water contaminant exposure)
- **Example**:
  ```sql
  INSERT INTO exposure (...) VALUES (
      12345,
      4167217,                          -- air pollution
      '2023-01-15',
      '2023-01-15',
      32534,                            -- environmental type
      45.2,                             -- PM2.5 level
      8840                              -- unit: µg/m³
  );
  ```

#### **B. Occupational Exposures (Chemical, Radiation)**
- **Concepts**: 
  - `40239056` (Occupational chemical exposure)
  - `4144272` (Radiation exposure)
- **Example**:
  ```sql
  INSERT INTO exposure (...) VALUES (
      12345,
      40239056,                         -- occupational chemical
      '2023-05-10',
      '2023-12-31',                     -- long-term exposure
      32535,                            -- occupational type
      8,                                -- hours/day
      8505                              -- unit: hours
  );
  ```

#### **C. Exposures from Claims Data**
- Use `exposure_type_concept_id = 32536` and map claims codes to OMOP concepts:
  ```sql
  INSERT INTO exposure (...) VALUES (
      12345,
      40163718,                         -- 'Exposure to asbestos' (OMOP concept)
      '2023-03-01',
      '2023-03-01',
      32536,                            -- claims-derived
      NULL,
      NULL,
      NULL,
      'ICD10: Z77.090'                  -- original code
  );
  ```

---

### **4. Mapping External Codes to OMOP Concepts**
For non-standard exposures (e.g., proprietary codes from environmental databases):
1. **Create a custom vocabulary**:
   ```sql
   INSERT INTO concept (
       concept_id, concept_name, domain_id, vocabulary_id, concept_class_id, standard_concept
   ) VALUES (
       2000000001,                     -- custom concept_id
       'EPA_PM2.5_Exposure',           -- name
       'Exposure',                     -- domain
       'EPA',                          -- vocabulary
       'Exposure',                     -- class
       NULL                            -- non-standard
   );
   ```
2. **Map to standard concepts** where possible using `CONCEPT_RELATIONSHIP`.

---

### **5. Querying External Exposures**
To analyze external exposures in ATLAS or SQL:
```sql
SELECT 
    e.person_id,
    c.concept_name AS exposure_type,
    e.exposure_start_date,
    e.quantity,
    u.concept_name AS unit
FROM exposure e
JOIN concept c ON e.exposure_concept_id = c.concept_id
LEFT JOIN concept u ON e.unit_concept_id = u.concept_id
WHERE e.exposure_type_concept_id = 32534  -- Environmental exposures
```

---

### **Key Resources**
1. [OMOP EXPOSURE Table Documentation](https://ohdsi.github.io/CommonDataModel/cdm54.html#EXPOSURE)
2. [OHDSI Vocabulary Recommendations](https://www.ohdsi.org/web/wiki/doku.php?id=documentation:vocabulary:exposure)
3. [Book of OHDSI Chapter on Exposures](https://ohdsi.github.io/TheBookOfOhdsi/Exposures.html)

Would you like help with a specific type of external exposure (e.g., occupational, environmental) or mapping a particular coding system?
