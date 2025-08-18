# The Gaia DataCatalog Guide
> [!NOTE]
> **Entries have properties based on the schema.org Dataset type which borrows from Dublin Core, DCAT and other specifications**

> [!TIP]
> **Entries are just the metadata**

> [!IMPORTANT]
> **Entries may include instructions for retrieving the actual data**

> [!WARNING]
> **We are in the process of identifying which properties of the schema.org Dataset type are necessary and which are optional here. We have not completed this task yet**

## Let's begin...
- [Dataset](https://schema.org/Dataset) has...
  - standard properties including name, description, dateCreated, dateModified, datePublished, expires, license, [citation](https://schema.org/citation), version, [keywords](https://schema.org/keywords), [measurementTechnique](https://schema.org/measurementTechnique), [measurementMethod](https://schema.org/measurementMethod), creator, funder and provider. See [here](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#roles-of-people) for an example of creator
  - mainEntity
    - Indicates the primary entity described in some page or other CreativeWork
    - Has a controlled vocabulary: "Place", "Person", "Household", "Establishment", "Entangled"
    - See [here](https://www.researchobject.org/ro-crate/specification/1.2/crate-focus.html) for some examples
  - includedInDataCatalog
    - A data catalog which contains this dataset
    - Our data catalog is named the GaiaCatalog
  - isBasedOn
    - A resource from which this work is derived or from which it is a modification or adaptation
    - Can take the form of an array of resources
    - See [here](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#indicating-a-source-dataset-schemaisbasedon-and-provwasderivedfrom) for an example
  - subjectOf
    - A [Claim](https://schema.org/Claim) about this Thing
    - Think of the Claim(s) a Dataset makes as its hypotheses. Minimally, a claim has...
      - An appearance that indicates an occurrence of a Claim in some CreativeWork
      - A firstAppearance that indicates the first known occurrence of a Claim in some CreativeWork
    - Can take the form of an array of claims
  - spatialCoverage
    - The spatialCoverage of a CreativeWork takes the place(s) which are the focus of the content
    - A spatialCoverage may take an array of [Place](https://schema.org/Place) when the scope of spatialCoverage includes more than one Place
    - A Place, in turn, takes minimally a name, a description and a [geo](https://schema.org/geo)
    - A geo, in turn, takes:
      - [GeoCoordinates](https://schema.org/GeoCoordinates) (See [here](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#use-geocoordinates-for-point-locations) for an example) and/or
      - [GeoShape](https://schema.org/GeoShape) (See [here](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#use-geoshape-for-all-other-location-types) for an example)
    - Use [additionalProperty](https://schema.org/additionalProperty) to identify the spatial reference system (e.g. WGS84). See [here](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#spatial-reference-systems) for an example
    - There is a second additionalProperty for spatialResolution that takes a value and a unitText
  - temporalCoverage
    - temporalCoverage is expressed in [ISO 8601](https://en.wikipedia.org/wiki/ISO_8601) format
  - distribution
    - A downloadable form of this dataset, at a specific location, in a specific format. This property can be repeated if different variations are available. There is no expectation that different downloadable distributions must contain exactly equivalent information. Different distributions might include or exclude different subsets of the entire dataset, for example
    - Takes either a [DataDownload](https://schema.org/DataDownload) or a [SearchAction](https://schema.org/SearchAction)
      - Takes a DataDownLoad when a distribution can be retrieved by a url. See [here](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#distributions) for an example
      - Takes a SearchAction when the distribution is retrieved through a service [endpoint](https://schema.org/EntryPoint) that takes [query parameters](https://schema.org/PropertyValueSpecification). See [here](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#accessing-data-through-a-service-endpoint) for an example
  - variableMeasured
    - Takes a [StatisticalVariable](https://schema.org/StatisticalVariable) when the exposure is an aggregate
      - Properties include a name, the statType (like a mean), the underlying measuredProperty of the statistic, the identifier (concept_id) of the underlying measuredProperty, a measurementQualifier for the unit of measurement of the underlying measuredProperty,  and, finally, a constraintProperty.
      - The measuredProperty the underlies a statistic may also have a minValue, a maxValue, the time span over which it was observed and this observation's margin of error.
      - Here constraintProperty takes an array of PropertyValue in which each PropertyValue ***disaggregates*** the measuredProperty statistic into smaller, more specific categories or groups
      - Here constraintProperty corresponds to a DataStructureDefinition in an [SDMX](https://sdmx.org/wp-content/uploads/SDMX_3-1-0_SECTION_2_FINAL.pdf) data cube or [RDF Data Cube](https://www.w3.org/TR/vocab-data-cube/). There are constraintProperty instances (implemented as PropertyValues) for dimensions and measurement attributes
      - As a rule, a StatisticalVariable has at least two constraints -- a timePeriod PropertyValue and a geographicalArea PropertyValue. timePeriod may have a duration like "per month" that we repeatedly observe from a start date. geographicalArea might be a raster cell and/or a vector shape derived from one or more raster cells. timePeriod and geographicalArea constraints are both dimensions. They group the measuredProperty statistic (like maximum temperature or PM2.5, producing a statistic like average maximum temperature per month repeatedly or the count of PM2.5 exceedance days per year repeatedly ***for*** an administrative area represented as a grid cell or a vector shape or, in the event there are more than one, ***by*** administrative area. In this event in an administrative area there would be a collection of grid cells and/or vector shapes.
      - Each constraint in the collection has its own unitText so, for example, the unit of measurement of an exposure statistic is a concatenation of the unit of measurement of the measuredProperty and its qualifiers. Take, for example, [Mean] [maximum temperature] [by month] [for a place]
    - In addition to zero or more StatisticalVariables, variableMeasured can host zero or more variables that are not statistics too
      - An exposure that is not a statistic takes a single [PropertyValue](https://schema.org/PropertyValue) following the [recommendation](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#tier-2-names-of-variables-with-formal-property-types) of [science-on-schema-org](https://github.com/ESIPFed/science-on-schema.org/blob/main/guides/Dataset.md#describing-a-dataset)  
      - Each of these PropertyValues in the variableMeasured array corresponds to an exposure definition
      - Each of these PropertyValues includes a propertyID. A [propertyID](https://schema.org/propertyID) corresponds to a concept_id in an external vocabulary. Take this propertyID for example: "http://gisextension.ohdsi.org/exposome/nnn"
      - Each of these PropertyValues includes an [AddAction](https://schema.org/AddAction) potentialAction through which an external exposure occurrence is added to the external_exposure OMOP CDM table
  - about
    - about takes any Thing including an [Event](https://schema.org/Event)
    - The Event has a potentialAction
    - potentialAction takes an array of actions
    - Each Action in the array includes an [object](https://schema.org/object) of type Dataset, a [result](https://schema.org/result) of type Dataset and the [instrument](https://schema.org/instrument) that produces the result from the object
    - Instrument takes [SoftwareApplication](https://schema.org/SoftwareApplication). Like [RO-Crate](https://www.researchobject.org/ro-crate/specification/1.2/provenance.html), here we use an instrument to create datasets
    - A SoftwareApplication has many properties including [featureList](https://schema.org/featureList), softwareVersion, releaseNotes, permissions, [availableOnDevice](https://schema.org/availableOnDevice) and downloadURL
    - Actions may form chains and chains may occur in parallel
    - So the array of actions taken by a potentialAction may trace the permutations that a Dataset traverses aka a [scientific workflow](https://jenkins-1.dataone.org/jenkins/view/Documentation%20Projects/job/ProvONE-Documentation-trunk/ws/provenance/ProvONE/v1/provone.html)
    - In the context of the OMOP CDM and the OHDSI analytics that runs on top of it, scientific workflows are a preprocessing step that produces place-based exposure occurrences for subsequent use in the Gaia toolchain
    - Recall that downstream in the toolchain exposures attach themselves to an OMOP Person by way of their locations over time and, from there, enter OHDSI analytics aka a machine learning AI
    - Ultimately, these scientific workflows go from ***Exposure2AI***
## Exposure2AI
> [!NOTE]
> Variables are drawn from the [Copernicus ERA5 reanalysis dataset](https://climatedataguide.ucar.edu/climate-data/era5-atmospheric-reanalysis#:~:text=ERA5%2C%20the%20successor%20to%20ERA,timely%20monitoring%20of%20the%20climate.)

> [!TIP]
> The Copernicus ERA5 reanalysis dataset offers hourly data with a spatial resolution of 0.25 degrees by 0.25 degrees. This corresponds to approximately 31 kilometers at mid-latitudes. The data covers the globe and includes various atmospheric, land surface, and ocean-wave variables. 

- So far two scientific workflows are in development as part of the HIV and Climate Change WG
  - One workflow goes from the Copernicus Climate Change Service to the construction of location and time specific variables for maximum temperature, minimum temperature, precipitation and humidity
  - The other workflow goes from the Copernicus Climate Change Service to the construction of location and time specific variables for “exceedances”. Exceedances are weather events that surpass a pre-defined limit or threshold
> [!IMPORTANT]
> There is the possibility of developing a third scientific workflow with a different Copernicus service -- one for air quality. Here we would partner with the Data Science Without Borders (DSWB) DGH/IRESSEF Air Quality WG
