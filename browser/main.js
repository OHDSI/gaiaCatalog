/* ************************************************************************** */
/*  main.js                                                               */
/*  A simple catalog browser for the OHDSI GIS extension                      */
/*  Tim Norris <tnorris@miami.edu>                                            */
/*  contributions by claude running gpt-oss:20b with ollama                   */
/* ************************************************************************** */

import { catalog } from './catalog.js';

const app = document.getElementById('app');

/* -------------------------------------------------------------------------- */
/*  json-ld configuration  **not working**                                    */
/* -------------------------------------------------------------------------- */

// const filterFields = ['keywords', 'measurementTechnique', 'variableMeasured']; // json-ld
// const description = 'description';
//       title = 'title';

/* -------------------------------------------------------------------------- */
/*  dcat configuration                                                        */
/* -------------------------------------------------------------------------- */

const filterFields = ['gdsc:collections', 'dcat:keyword', 'locn:geometry', 'adms:representationTechnique', 'dct:rights']; // dcat
const searchFields = ['dcat:keyword', 'locn:geometry', 'adms:representationTechnique', 'dct:rights', 'dct:title', 'dct:description', 'gdsc:attributes']; // dcat
const descriptionField = 'dct:description',
      titleField = 'dct:title';

/* -------------------------------------------------------------------------- */
/*  State & helper data                                                       */
/* -------------------------------------------------------------------------- */

let filters = filterFields.reduce((accumulator, field) => {
  accumulator[field] = new Set();
  return accumulator;
}, {});

/* store unique values per field */
const fieldOptions = filterFields.reduce((accumulator, field) => {
  accumulator[field] = new Set();
  return accumulator;
}, {});

/* counts for each value – used for the “(count)” label */
let fieldCounts = filterFields.reduce((accumulator, field) => {
  accumulator[field] = new Map();
  return accumulator;
}, {});

/* keep track of which field’s “Show more” is expanded */
const expanded = filterFields.reduce((accumulator, field) => {
  accumulator[field] = false;
  return accumulator;
}, {});

let searchString = '';
let loadedTables = new Set();
let loadedVariables = new Set();

/* -------------------------------------------------------------------------- */
/*  Utility helpers                                                           */
/* -------------------------------------------------------------------------- */

function escapeHtml(s) {
  return s.replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;',
    '"': '&quot;', "'": '&#39;'
  })[c]);
}

function normalizeField(value) {
  if (Array.isArray(value)) return value.map(v => typeof v === 'object' ? v.name || '' : v);
  if (typeof value === 'object') return [value.name || ''];
  return [value];
}

/* -------------------------------------------------------------------------- */
/*  Build lookup tables (values + counts)                                     */
/* -------------------------------------------------------------------------- */

function initFieldOptions() {
  catalog.forEach(entry => {
    filterFields.forEach(field => {
      const vals = normalizeField(entry[field]);
      vals.forEach(v => {
        fieldOptions[field].add(v);
        const map = fieldCounts[field];
        map.set(v, (map.get(v) || 0) + 1);
      });
      fieldCounts[field] = new Map([...fieldCounts[field].entries()].sort((a,b) => b[1] - a[1]));
      fieldOptions[field] = new Set(fieldCounts[field].keys());
    });
  });
}

/* -------------------------------------------------------------------------- */
/*  UI – Settings modal                                                       */
/* -------------------------------------------------------------------------- */

const DEFAULT_pgEndpoint = 'http://localhost:3000/rpc/'; // optional default

// read pgEndpoint from localStorage, if any
const storedpgEndpoint = localStorage.getItem('pgEndpoint');
const pgEndpoint = storedpgEndpoint || DEFAULT_pgEndpoint;
localStorage.setItem('postgrestConnected', false);

function showSettings() {
  const modal = document.getElementById('settingsModal');
  modal.classList.remove('hidden');
  document.getElementById('pgEndpointInput').value = pgEndpoint;
}

function hideSettings() {
  document.getElementById('settingsModal').classList.add('hidden');
}

document.getElementById('settingsBtn').addEventListener('click', showSettings);
document.getElementById('closeSettings').addEventListener('click', hideSettings);

document.getElementById('pgEndpointForm').addEventListener('submit', async e => {
  e.preventDefault();
  const url = document.getElementById('pgEndpointInput').value.trim();
  if (!url) return;
  localStorage.setItem('pgEndpoint', url);
  hideSettings();
  // check if the endpoiint is repsponding with the public schema
  try {
    await callPostgrest('gdsc_get_schema_tables', {"schema_name": "public"});
    localStorage.setItem('postgrestConnected', true);    
    alert('Connection success!!');
    render();
  } catch (err) {
    alert('Could not connect to database.');
    console.error(err);
  }
});

/* -------------------------------------------------------------------------- */
/*  Integration with PostGIS                                                  */
/* -------------------------------------------------------------------------- */

let api_url = '';

async function callPostgrest(func, params) {
  const shell = 'bash';

  try {
    const response = await fetch(`${pgEndpoint}${func}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json' // could put jwt auth here ...
      },
      body: JSON.stringify(params)
    });

    if (!response.ok) throw new Error(`HTTP error! Status: ${response.status}`);

    const data = await response.json();
    console.log('Success:', data);
    return data;
  } catch (error) {
    console.error('Post failed:', error);
  }

}

async function loadlayer(table) {
  if (loadedTables.has(table)) {
    console.log(`table ${table} already loaded`);
    return;
  }
  console.log(`loading table ${table}.`);

  /* load dependencies if any */
  const response = await callPostgrest('gdsc_path_and_dependencies',{"table_id": table});
  const dataPath = response.split('\n')[0];
  const tablesToLoad = response.split('\n').slice(1);
  for (const tableToLoad of tablesToLoad) { await loadLayer(tableToLoad); };

  /* load the table */
  for (const script of ['osgeo','postgis']) {
    console.log(`${dataPath}/etl/${table}_${script}`);
    const response = await callPostgrest(
      'gdsc_exec',
      {
        "shell": "bash",
        "script": `${dataPath}/etl/${table}_${script}`
      }
    );
  };

  /* update the status */
  render();

}

async function loadvar(table,variable) {
  if (loadedVariables.has(variable)) {
    console.log(`variable ${variable} for table ${table} already loaded`);
    return;
  }
  console.log(`loading variable ${variable} from ${table}.`);

  /* make sure the layer is loaded */
  if (!loadedTables.has(table)) await loadlayer(table);

  /* construct the parameters */
  const entry = catalog.find(e => e['gdsc:tablename'] === table);
  const attribute = entry['gdsc:attributes'].find(e => e.includes(variable)).split(';');
  const parameters = {
    "params": {
      "table_id": table,
      "table_description": entry['dct:description'],
      "geom_type": entry['locn:geometry'],
      "geom_label": entry['gdsc:label'],
      "variable_nodata": entry['gdsc:nodata'] ? entry['gdsc:nodata'][1] : "" ,
      "variable_id": attribute[0], 
      "description": attribute[1].replaceAll('"', ''),
      "source": attribute[2],
      "type": attribute[3],
      "unit": attribute[4],
      "unit_concept_id": attribute[5] == '' ? "" : parseInt(attribute[5]),
      "min_val": attribute[6] == '' ? "" : parseFloat(attribute[6]),
      "max_val": attribute[7] == '' ? "" : parseFloat(attribute[7]),
      "start_date": new Date(attribute[8]).toISOString().slice(0,10),
      "end_date": new Date(attribute[9]).toISOString().slice(0,10),
      "concept_id": attribute[10] == '' ? "" : parseInt(attribute[10])      
    }
  }

  // load the variable
  const response = await callPostgrest(
    'gdsc_load_variable',parameters
  );

  render();
}

/* -------------------------------------------------------------------------- */
/*  Render filter accordion                                                   */
/* -------------------------------------------------------------------------- */

function renderFilters(parent) {
  const filterTitle = document.createElement('h5');
  filterTitle.textContent = 'Filters';

  const accordion = document.createElement('div');
  accordion.className = 'accordion';
  accordion.id = 'filterAccordion';

  filterFields.forEach((field, idx) => {
    const card = document.createElement('div');
    card.className = 'accordion-item';

    /* Header button */
    const header = document.createElement('h2');
    header.className = 'accordion-header';
    header.id = `heading-${field}`;

    const button = document.createElement('button');
    button.className = 'accordion-button';
    button.type = 'button';
    button.setAttribute('data-bs-toggle', 'collapse');
    button.setAttribute('data-bs-target', `#collapse-${field}`);
    if ( idx == currentAccordian ) { 
      button.setAttribute('aria-expanded', 'true');
    } else {
      button.setAttribute('aria-expanded', 'false');
      button.className += ' collapsed';
    }
    button.setAttribute('aria-controls', `collapse-${field}`);
    button.textContent = field.replace(/([A-Z])/g, ' $1');
    button.addEventListener('click', () => {
      currentAccordian = idx;
    });

    header.appendChild(button);
    card.appendChild(header);

    /* Collapse body */
    const collapse = document.createElement('div');
    collapse.id = `collapse-${field}`;
    collapse.className = 'accordion-collapse collapse';
    if ( idx == currentAccordian ) { collapse.className += ' show'; }
    collapse.setAttribute('aria-labelledby', `heading-${field}`);
    collapse.setAttribute('data-bs-parent', '#filterAccordion');

    const body = document.createElement('div');
    body.className = 'accordion-body';

    /* Build the list of checkboxes */
    const options = Array.from(fieldOptions[field]);
    const optionElems = [];
    options.forEach(opt => {
      const label = document.createElement('label');
      label.className = 'form-check form-check-inline w-100';

      const input = document.createElement('input');
      input.className = 'form-check-input';
      input.type = 'checkbox';
      input.value = opt;
      if (filters[field].has(opt)) { input.checked = true; }
      input.addEventListener('change', () => {
        if (input.checked) filters[field].add(opt);
        else filters[field].delete(opt);
        render(); // re‑render the result list
      });

      const count = fieldCounts[field].get(opt) || 0;
      const countSpan = document.createElement('span');
      countSpan.className = 'badge badge-pill bg-light text-dark';
      countSpan.textContent = `(${count})`;

      label.appendChild(input);
      label.appendChild(document.createTextNode(` ${opt}`));
      label.appendChild(countSpan);
      body.appendChild(label);
      optionElems.push(label);
    });

    /* Show‑more toggle (only if >5 options) */
    if (options.length > 5) {
      const moreOrLessBtn = document.createElement('button');
      moreOrLessBtn.className = 'btn btn-sm mt-2 text-primary border-0';
      moreOrLessBtn.textContent = 'show more ...';
      moreOrLessBtn.addEventListener('click', () => {
        if (optionElems[5].style.display == 'none') {
          optionElems.slice(5).forEach(el => el.style.display = 'block');
          moreOrLessBtn.textContent = '... show less';
        } else {
          optionElems.slice(5).forEach(el => el.style.display = 'none');
          moreOrLessBtn.textContent = 'show more ...';
        }
      });
      optionElems.slice(5).forEach(el => el.style.display = 'none');
      body.appendChild(moreOrLessBtn);
    }

    collapse.appendChild(body);
    card.appendChild(collapse);
    accordion.appendChild(card);
  });

  parent.appendChild(filterTitle);
  parent.appendChild(accordion);
}

/* -------------------------------------------------------------------------- */
/*  Render filter pills                                                       */
/* -------------------------------------------------------------------------- */

function renderFilterPills(parent) {
  const filterPills = document.createElement('div');
  filterPills.className = 'p-1 mt-1 filter-pills';
  filterFields.forEach((field, idx) => {
    filters[field].forEach(filter => {
      const filterPill = document.createElement('span');
      filterPill.className = 'badge rounded-pill bg-light text-dark border d-inline-flex align-items-center p-1';
      const filterText = document.createElement('span');
      filterText.className = 'me-2';
      filterText.textContent = filter;
      const closeButton = document.createElement('button');
      closeButton.type = 'button';
      closeButton.className = 'btn-close';
      closeButton.setAttribute('aria-label', 'close');
      closeButton.addEventListener('click', () => { 
        filters[field].delete(filter);
        render();
      });
      filterPill.appendChild(filterText);
      filterPill.appendChild(closeButton);
      filterPills.appendChild(filterPill);
    });
  });
  parent.appendChild(filterPills);
}

/* -------------------------------------------------------------------------- */
/*  Search / filter helpers                                                   */
/* -------------------------------------------------------------------------- */

function buildSearchString(entry) {
  var parts = [
    entry[titleField] || '',
    entry[descriptionField] || ''
  ];
  searchFields.forEach(field => { parts.push(...normalizeField(entry[field])) });
  return parts.join(' ').toLowerCase();
}

function matchesFilters(entry) {
  return filterFields.every(field => {
    const selected = filters[field];
    if (selected.size === 0) return true;
    const values = normalizeField(entry[field]);
    return values.some(v => selected.has(v));
  });
}

function matchesQuery(entry, query) {
  if (!query) return true;
  return buildSearchString(entry).includes(query);
}

/* -------------------------------------------------------------------------- */
/*  Rendering result cards                                                    */
/* -------------------------------------------------------------------------- */

function renderResults(entries) {
  const container = document.createElement('div');
  container.id = 'resultsContainer';

  const ul = document.createElement('ul');
  ul.id = 'results';
  ul.className = 'ps-0';
  entries.forEach(entry => {
    const li = document.createElement('li');
    const a = document.createElement('a');
    a.href = `#entry/${entry.id}`;

    const card = document.createElement('div');
    card.className = 'card';

    /* layer title */
    const title = document.createElement('h2');
    title.textContent = entry[titleField] || entry.id;
    /* status circle and load button */
    const status = document.createElement('div');
    status.id = `layer-${entry['gdsc:tablename']}`;
    status.className = 'float-left circle';
    status.className += loadedTables.has(entry['gdsc:tablename']) 
      ? ' green-fill' 
      : ' red-fill';
    status.addEventListener('click', (e) => { 
      e.preventDefault();
      loadlayer(entry['gdsc:tablename']); 
    });
    title.appendChild(status);
    card.appendChild(title);

    /* shortened description */
    const desc = document.createElement('p');
    desc.textContent = entry[descriptionField]
      ? entry[descriptionField].slice(0, 120) + '…'
      : 'No description.';
    card.appendChild(desc);
    a.appendChild(card);
    li.appendChild(a);
    ul.appendChild(li);
  });
  container.appendChild(ul);
  return container;
}

/* -------------------------------------------------------------------------- */
/*  Main view – search + filters + results                                    */
/* -------------------------------------------------------------------------- */

function renderSearch() {
  app.innerHTML = '';

  /* Header and title */
  const banner = document.createElement('div');
  banner.id = 'bannerWrapper';

  const header = document.createElement('header');
  header.innerHTML = '<h1>OHDSI GIS Catalog Browser</h1>';
  banner.appendChild(header);

  /* search box */
  const searchBox = document.createElement('input');
  searchBox.type = 'text';
  searchBox.placeholder = 'Free‑text search…';
  searchBox.value = searchString;
  searchBox.setAttribute('autofocus', '');
  searchBox.addEventListener('input', () => {
    searchString = searchBox.value;
    if (searchString.length > 2 || searchString.length == 0) {
      const right = document.getElementById('resultsPane');
      right.innerHTML = '';
      const results = catalog.filter(entry =>
        matchesFilters(entry) &&
        matchesQuery(entry, searchString.trim().toLowerCase())
      );
      right.appendChild(renderResults(results));
    }
  });
  banner.appendChild(searchBox);

  /* Wrapper for the two columns */
  const wrapper = document.createElement('div');
  wrapper.id = 'searchWrapper';

  /* Left column – filters */
  const left = document.createElement('aside');
  left.id = 'filterPane';

  renderFilters(left);
  wrapper.appendChild(left);

  /* Right column – results */
  const right = document.createElement('div');
  right.id = 'resultsWrapper';
  right.className = 'container-fluid';
  const rightResults = document.createElement('main');
  rightResults.id = 'resultsPane';

  const results = catalog.filter(entry =>
    matchesFilters(entry) &&
    matchesQuery(entry, searchString.trim().toLowerCase())
  );
  renderFilterPills(right);
  rightResults.appendChild(renderResults(results));
  right.appendChild(rightResults);
  wrapper.appendChild(right);

  app.appendChild(banner);
  app.appendChild(wrapper);
}

/* -------------------------------------------------------------------------- */
/*  Detailed view – entry landing page                                        */
/* -------------------------------------------------------------------------- */

function renderLanding(entry) {
  app.innerHTML = '';

  /* render a metadata element with title and content */
  function renderElement(title, value) {
    const section = document.createElement('div');
    const heading = document.createElement('h5');
    heading.className = 'detail-element';
    heading.textContent = title.replace(/([A-Z])/g, ' $1');
    section.appendChild(heading);

    let content = value;
    if (typeof value === 'string') {
      content = document.createElement('p');
      content.textContent = value;
    }
    section.appendChild(content);
    
    wrapper.appendChild(section);
  }

 /* Header and title detail page */
  const banner = document.createElement('div');
  banner.id = 'bannerWrapper';

  const header = document.createElement('header');
  header.innerHTML = '<h1>OHDSI GIS Catalog Browser</h1>';
  banner.appendChild(header);
  app.appendChild(banner);

  const back = document.createElement('a');
  back.href = '#';
  back.className = 'back-link p-2';
  back.textContent = '← Back to results';
  app.appendChild(back);

  /* content wrapper for layer */
  const wrapper = document.createElement('div');
  wrapper.className = 'card m-1';

  /* title for layer */
  const title = document.createElement('h1');
  title.className = 'detail-title';
  title.textContent = entry[titleField] || entry.id;
  const status = document.createElement('div');
  status.id = `layer-${entry['gdsc:tablename']}`;
  status.className = 'float-left circle';
  status.className += loadedTables.has(entry['gdsc:tablename'])
    ? ' green-fill'
    : ' red-fill';
  status.addEventListener('click', () => { loadlayer(entry['gdsc:tablename']); });
  title.appendChild(status);
  wrapper.appendChild(title);

  /* render all filter fields and the description */
  const fields = [descriptionField, ...filterFields];
  fields.forEach(field => {
    if (!entry[field]) return;
    const val = normalizeField(entry[field])
      .map(v => escapeHtml(v))
      .join(', ');
    renderElement(field,val);
  });

  /* attributes */
  const attrWrapper = document.createElement('div');
  attrWrapper.className='container-fluid mt-2 ms-0 ps-0 text-break';
  const attrFluid = document.createElement('div');
  attrFluid.className='container-fluid';
  const attrFluidRow = document.createElement('div');
  attrFluidRow.className='row';
  const attrWrapScroll = document.createElement('div');
  attrWrapScroll.className='wrapScroll';
  const attrs = document.createElement('table');
  attrs.className = 'table table_morecondensed table-striped w-auto';
  const attrHeader = document.createElement('thead');
  const headerRow = document.createElement('tr');
  const attrHeaders = new Map([
    ['Status',-99],
    ['Name',0],
    ['Description',1],
    ['Type',3],
    ['Unit',4],
    ['Unit Concept ID',5],
    ['Min Val',6],
    ['Max Val',7],
    ['Start Date',8],
    ['End Date',9],
    ['Concept ID',10]
  ]);
  attrHeaders.keys().forEach(header => {
    const headerElement = document.createElement('th');
    headerElement.textContent = header;
    headerRow.appendChild(headerElement);
  });
  attrHeader.appendChild(headerRow);
  const attrBody = document.createElement('tbody');
  entry['gdsc:attributes'].forEach(attribute => {
    const attrRow = document.createElement('tr');
    const attrSpec = attribute.split(';');
    attrHeaders.keys().forEach(header => {
      const attrElement = document.createElement('td');
      if (attrHeaders.get(header) < 0) {
        // button to load variable
        const buttonWrap = document.createElement('div');
        buttonWrap.className = 'none';
        const button = document.createElement('div');
        button.id = `variable-${attrSpec[0]}`;
        button.className = 'float-left circle';
        button.className += loadedVariables.has(attrSpec[0])
          ? ' green-fill'
          : ' red-fill';
        button.addEventListener('click', () => { loadvar(entry['gdsc:tablename'],attrSpec[0]); });
        buttonWrap.appendChild(button);
        attrElement.appendChild(buttonWrap);
      } else {
        if (attrSpec[attrHeaders.get(header)]) {
          if (attrSpec[attrHeaders.get(header)] .length > 42) {
            //attrElement.setAttribute('type', 'button');
            attrElement.textContent = attrSpec[attrHeaders.get(header)].slice(0,42) + '...'
            attrElement.setAttribute('data-bs-toggle', 'tooltip');
            attrElement.setAttribute('data-bs-placement', 'top');
            attrElement.setAttribute('data-bs-custom-class', 'custom-tooltip');
            attrElement.setAttribute('data-bs-container', 'body');
            attrElement.setAttribute('title', attrSpec[attrHeaders.get(header)]);
          } else {
            attrElement.textContent = attrSpec[attrHeaders.get(header)];
          }
        }
      }
      attrRow.appendChild(attrElement);
    });
    attrBody.appendChild(attrRow);
  });
  attrs.appendChild(attrHeader);
  attrs.appendChild(attrBody);
  attrWrapScroll.appendChild(attrs);
  attrFluidRow.appendChild(attrWrapScroll);
  attrFluid.appendChild(attrFluidRow);
  attrWrapper.appendChild(attrFluid);
  renderElement('gdsc:attributes',attrWrapper);

  app.appendChild(wrapper);

}

/* -------------------------------------------------------------------------- */
/*  Router – decides which view to show                                       */
/* -------------------------------------------------------------------------- */

async function render() {
  if (localStorage.getItem('postgrestConnected') == 'true') {
    loadedTables.clear();
    const loaded = await callPostgrest('gdsc_get_schema_tables',{"schema_name": "public"});
    loaded.forEach(layer => { loadedTables.add(layer); })
  }
  const hash = window.location.hash;
  if (!hash || hash === '#') {
    renderSearch();
  } else if (hash.startsWith('#entry/')) {
    const id = hash.slice(7);
    const entry = catalog.find(e => e.id === id);
    if (entry) {
      if (localStorage.getItem('postgrestConnected') == 'true') {
        loadedVariables.clear();
        const loaded = await callPostgrest(
          'gdsc_get_loaded_variables_for_table',
          {"table_id": entry['gdsc:tablename']}
        );
        if (loaded) loaded.forEach(variable => { loadedVariables.add(variable); });
      }
      renderLanding(entry);
    } else app.textContent = 'Entry not found.';
  } else {
    // Unknown hash – fall back to search view
    renderSearch();
  }
}

/* -------------------------------------------------------------------------- */
/*  Init & routing                                                            */
/* -------------------------------------------------------------------------- */

initFieldOptions();
window.addEventListener('hashchange', render);
let currentAccordian = 0;
render();