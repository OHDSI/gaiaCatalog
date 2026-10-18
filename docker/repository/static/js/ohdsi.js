const progressModal = new bootstrap.Modal(document.getElementById("progressModal"));
document.getElementById('closeProgress').addEventListener('click', e => progressModal.hide());
const progressContent = document.getElementById('progressContent');

var startSpinner = function() {
  const progress_indicator = document.getElementById(`progressSpinner`);
  progress_indicator.className = 'yin-yang yin-yang-large';
  const button = document.getElementById('closeProgress');
  button.disabled = true;
  button.classList.add('disabled');
  button.innerText = 'loading...';
};

var stopSpinner = function() {
  const progress_indicator = document.getElementById(`progressSpinner`);
  progress_indicator.classList.remove('yin-yang','yin-yang-large');
  const button = document.getElementById('closeProgress');
  button.disabled = false;
  button.classList.remove('disabled');
  button.innerText = 'close';
};

var addProgressMessage = function(message) {
  const progressMessage = document.createElement('pre');
  if (message.includes('**')) { 
    progressMessage.className = 'progress-success';
    const progress_indicator = document.getElementById(`progressSpinner`);
    progress_indicator.className = '';
    const button = document.getElementById('closeProgress');
    button.disabled = false;
    button.classList.remove('disabled');
    button.innerText = 'Close';
  }
  if (message.includes('failed')) progressMessage.className = 'progress-fail';
  progressMessage.textContent = message.replaceAll('\\n', '\n');
  progressContent.appendChild(progressMessage);
  const lastElement = progressContent.lastElementChild;
  lastElement.scrollIntoView({ behavior: 'smooth' });
};

var callApi = async function(api_call, status, message) {
  const response = await fetch(api_call, {method: 'POST'});

  if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);

  // Get the stream reader and text decoder
  const reader = response.body.getReader();
  const decoder = new TextDecoder("utf-8");

  while (true) {
      // Read next chunk from stream
      const { done, value } = await reader.read();
      
      if (done) {
          addProgressMessage(message);
          console.log(decoder.decode(value, { stream: true }));
          console.log(message);
          status.className = 'float-left circle small-circle green-fill';
          stopSpinner();
          break;
      }

      // Decode the unit8array chunk into a string and append it to the DOM
      const chunkText = decoder.decode(value, { stream: true });
      console.log(chunkText);
      addProgressMessage(chunkText);
  }
}

var loadLayer = async function(layer) {
  progressContent.textContent = "";
  const status_indicator = document.getElementById(`layer-${layer}`);
  status_indicator.className = 'yin-yang yin-yang-small';
  startSpinner();
  progressModal.show();
  console.log(`loading table ${layer}.`);
  try {
    await callApi(`/load/${layer}`,status_indicator,`**Finished ETL for ${layer}**`);
  } catch (error) {
    console.error("ETL failed streaming error:", error);
    progressContent.textContent = "An error occurred while streaming.";
  }
};

var loadVar = async function(layer,variable) {
  progressContent.textContent = "";
  const layer_status_indicator = document.getElementById(`layer-${layer}`);
  if (layer_status_indicator.classList.contains('red-fill')) {
    layer_status_indicator.className = 'yin-yang yin-yang-small';
  }
  const status_indicator = document.getElementById('variable-'+variable);
  status_indicator.className = 'yin-yang yin-yang-small';
  startSpinner();
  progressModal.show();
  console.log(`loading varaible ${variable} for ${layer}.`);
  try {
    await callApi(`/load/${layer}/${variable}`,status_indicator,`**Finished ETL for for ${variable} of ${layer}**`);
    if (layer_status_indicator.classList.contains('yin-yang')) {
      layer_status_indicator.className = 'float-left circle small-circle green-fill';
    }
  } catch (error) {
    console.error("ETL failed streaming error:", error);
    progressContent.textContent = "An error occurred while streaming.";
  }

};