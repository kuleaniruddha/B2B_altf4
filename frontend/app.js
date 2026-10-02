const form = document.getElementById("upload-form");
const imageInput = document.getElementById("image-input");
const preview = document.getElementById("preview");
const dropzoneText = document.getElementById("dropzone-text");
const statusEl = document.getElementById("status");
const submitBtn = document.getElementById("submit-btn");
const emptyState = document.getElementById("empty-state");
const results = document.getElementById("results");

imageInput.addEventListener("change", () => {
  const file = imageInput.files?.[0];
  if (!file) return;
  dropzoneText.hidden = true;
  preview.hidden = false;
  preview.src = URL.createObjectURL(file);
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const file = imageInput.files?.[0];
  if (!file) {
    statusEl.textContent = "Choose an image first.";
    return;
  }

  submitBtn.disabled = true;
  statusEl.textContent = "Running Jansampark pipeline...";

  const formData = new FormData();
  formData.append("image", file);
  formData.append("lat", document.getElementById("lat").value);
  formData.append("lon", document.getElementById("lon").value);

  try {
    const response = await fetch("/analyze-image", {
      method: "POST",
      body: formData,
    });
    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(errorText || "Analysis failed.");
    }
    const payload = await response.json();
    renderResults(payload);
    statusEl.textContent = "Analysis complete.";
  } catch (error) {
    statusEl.textContent = error.message || "Something went wrong.";
  } finally {
    submitBtn.disabled = false;
  }
});

function renderResults(payload) {
  emptyState.hidden = true;
  results.hidden = false;

  document.getElementById("issue-badge").textContent = payload.issueLabel;
  document.getElementById("severity-badge").textContent = payload.severity;
  document.getElementById("trust-badge").textContent = payload.trustStatus;
  document.getElementById("report-id").textContent = payload.reportId;
  document.getElementById("department-id").textContent = payload.departmentId;
  document.getElementById("issue-label").textContent = payload.issueLabel;
  document.getElementById("issue-confidence").textContent = `${(payload.confidence * 100).toFixed(1)}%`;
  document.getElementById("waste-label").textContent = payload.wastePredictions?.[0]?.label || "n/a";
  document.getElementById("inference-mode").textContent = payload.inference?.mode || "unknown";
  document.getElementById("auth-score").textContent = payload.authenticity.score;
  document.getElementById("auth-exif").textContent = payload.authenticity.exif_present ? "Yes" : "No";
  document.getElementById("auth-gps").textContent = payload.authenticity.gps_present ? "Yes" : "No";
  document.getElementById("auth-reasons").textContent = payload.authenticity.reasons?.join(", ") || "none";
  document.getElementById("hash-value").textContent = payload.hash;
  document.getElementById("duplicate-of").textContent = payload.duplicateOf || "No duplicate found";
  document.getElementById("review-required").textContent = payload.reviewRequired ? "Yes" : "No";
  document.getElementById("lat-detector").textContent = `${payload.latencyMs.detector_ms} ms`;
  document.getElementById("lat-classifier").textContent = `${payload.latencyMs.classifier_ms} ms`;
  document.getElementById("lat-total").textContent = `${payload.latencyMs.total_ms} ms`;
  document.getElementById("raw-json").textContent = JSON.stringify(payload, null, 2);

  results.scrollIntoView({ behavior: "smooth", block: "start" });
}
