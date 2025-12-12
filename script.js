let points = [];

// Add row
document.getElementById("add-row").addEventListener("click", () => {
  points.push({ x: "", y: "" });
  renderTable();
});

// Render table
function renderTable() {
  const body = document.getElementById("points-body");
  body.innerHTML = "";

  points.forEach((p, i) => {
    const row = document.createElement("tr");

    row.innerHTML = `
      <td><input type="number" value="${p.x}" data-i="${i}" data-field="x"></td>
      <td><input type="number" value="${p.y}" data-i="${i}" data-field="y"></td>
      <td><button class="delete-btn" data-del="${i}">X</button></td>
    `;

    body.appendChild(row);
  });
}

// Handle table edits
document.addEventListener("input", e => {
  if (e.target.dataset.field) {
    const i = e.target.dataset.i;
    points[i][e.target.dataset.field] = parseFloat(e.target.value);
  }
});

// Delete point
document.addEventListener("click", e => {
  if (e.target.dataset.del !== undefined) {
    points.splice(e.target.dataset.del, 1);
    renderTable();
  }
});

// Interpolate
document.getElementById("interp-x").addEventListener("input", () => {
  const x = parseFloat(document.getElementById("interp-x").value);
  const output = document.getElementById("output");

  if (isNaN(x) || points.length < 2) {
    output.textContent = "";
    return;
  }

  // Sort by X
  const sorted = points.filter(p => !isNaN(p.x) && !isNaN(p.y))
                       .sort((a,b) => a.x - b.x);

  // Find interval
  for (let i=0; i<sorted.length-1; i++) {
    if (x >= sorted[i].x && x <= sorted[i].x+Number.EPSILON || x <= sorted[i+1].x) {
      const x1 = sorted[i].x;
      const y1 = sorted[i].y;
      const x2 = sorted[i+1].x;
      const y2 = sorted[i+1].y;

      const y = y1 + ((y2 - y1) * (x - x1)) / (x2 - x1);
      output.textContent = "Y = " + y.toFixed(4);
      return;
    }
  }

  output.textContent = "X is outside the range.";
});

// Register service worker
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("./service-worker.js");
}

renderTable();
