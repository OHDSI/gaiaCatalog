# OMOP Common Data Model: External Exposure Table

The OMOP Common Data Model (CDM) developed by OHDSI includes the EXPOSURE table to capture information about patient exposures to various substances or treatments. However, there isn't a specific "EXTERNAL_EXPOSURE" table in the standard OMOP CDM.

## Exposure Table in OMOP CDM

The standard EXPOSURE table contains:
- `exposure_id`: Primary key identifier
- `person_id`: Foreign key to the PERSON table
- `exposure_concept_id`: Concept representing the exposure
- `exposure_start_date`: When the exposure began
- `exposure_end_date`: When the exposure ended
- `exposure_type_concept_id`: Categorizes the source/type of exposure data
- `quantity`: Amount of exposure
- `unit_concept_id`: Unit of measurement

## Handling External Exposures

For exposures that come from external sources (outside the primary EHR system), you have several options:

1. **Use the EXPOSURE table** with appropriate type concepts:
   - Set `exposure_type_concept_id` to indicate an external source
   - Use the `visit_detail_id` field to link to external encounter information

2. **Create a custom extension table**:
   ```
   CREATE TABLE EXT_EXTERNAL_EXPOSURE (
     external_exposure_id INT PRIMARY KEY,
     exposure_id INT FOREIGN KEY REFERENCES EXPOSURE(exposure_id),
     external_source VARCHAR(255),
     external_id VARCHAR(255),
     additional_metadata VARCHAR(MAX)
   );
   ```

3. **Use the OBSERVATION table** for exposures that don't fit well in the EXPOSURE model

## OHDSI Recommendations

OHDSI recommends using the standard EXPOSURE table whenever possible, with appropriate concept mappings. For external data:
- Map to standard concepts where available
- Document the source system in the `exposure_type_concept_id` or `visit_occurrence_id`
- Consider using the NOTE table to capture unstructured details

Would you like more specific information about how to model a particular type of external exposure in the OMOP CDM?
