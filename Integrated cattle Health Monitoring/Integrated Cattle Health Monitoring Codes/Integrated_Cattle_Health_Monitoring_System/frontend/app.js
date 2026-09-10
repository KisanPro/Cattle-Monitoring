const API_BASE = 'http://127.0.0.1:5055/api/v1';

let chartInstance = null;
let currentCattleId = 'KA-1989';

document.addEventListener('DOMContentLoaded', () => {
    lucide.createIcons();
    setupEventListeners();
    loadDashboard(currentCattleId);
});

function setupEventListeners() {
    const selectEl = document.getElementById('cattle-select');
    selectEl.addEventListener('change', (e) => {
        currentCattleId = e.target.value;
        loadDashboard(currentCattleId);
    });

    // Form handlers for simulator
    document.getElementById('milk-sim-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const qty = parseFloat(document.getElementById('sim-milk-qty').value);
        const shift = document.getElementById('sim-milk-shift').value;
        const todayStr = new Date().toISOString().split('T')[0];

        try {
            await fetch(`${API_BASE}/ingest/milk/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    cattle_id: currentCattleId,
                    record_date: todayStr,
                    shift: shift,
                    quantity_liters: qty
                })
            });
            alert('Milk record successfully ingested from APK simulator!');
            loadDashboard(currentCattleId);
        } catch (err) {
            console.error(err);
            alert('Failed to submit milk record: ' + err.message);
        }
    });

    document.getElementById('weight-sim-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const weight = parseFloat(document.getElementById('sim-weight-val').value);
        const bcs = parseFloat(document.getElementById('sim-bcs-val').value);
        const todayStr = new Date().toISOString().split('T')[0];

        try {
            await fetch(`${API_BASE}/ingest/weight/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    cattle_id: currentCattleId,
                    record_date: todayStr,
                    weight_kg: weight,
                    bcs_score: bcs
                })
            });
            alert('Weight record successfully ingested from APK simulator!');
            loadDashboard(currentCattleId);
        } catch (err) {
            console.error(err);
            alert('Failed to submit weight record: ' + err.message);
        }
    });

    document.getElementById('vac-sim-form').addEventListener('submit', async (e) => {
        e.preventDefault();
        const vacName = document.getElementById('sim-vac-name').value;
        const dueDate = document.getElementById('sim-vac-due').value;
        const todayStr = new Date().toISOString().split('T')[0];

        try {
            await fetch(`${API_BASE}/ingest/vaccination/`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    cattle_id: currentCattleId,
                    vaccine_name: vacName,
                    administered_date: todayStr,
                    next_due_date: dueDate,
                    status: 'Up to Date'
                })
            });
            alert('Vaccine record successfully ingested from APK simulator!');
            loadDashboard(currentCattleId);
        } catch (err) {
            console.error(err);
            alert('Failed to submit vaccine record: ' + err.message);
        }
    });
}

async function loadDashboard(cattleId) {
    try {
        // 1. Fetch Cattle metadata
        const metaRes = await fetch(`${API_BASE}/registry/cattles/${cattleId}`);
        if (metaRes.ok) {
            const meta = await metaRes.json();
            document.getElementById('cattle-breed').textContent = meta.breed;
            document.getElementById('cattle-age').textContent = `${meta.age_years} Years`;
            document.getElementById('farm-id-display').textContent = meta.farm_id;
        }

        // 2. Fetch AI Health Assessment
        const assessRes = await fetch(`${API_BASE}/health/assess/${cattleId}?as_of=2026-09-04`);
        if (assessRes.ok) {
            const assessment = await assessRes.json();
            renderAssessment(assessment);
        }

        // 3. Fetch Synchronized Time-Series Chart Data
        const tsRes = await fetch(`${API_BASE}/health/timeseries/${cattleId}`);
        if (tsRes.ok) {
            const tsData = await tsRes.json();
            renderChart(tsData.timeline);
        }

        lucide.createIcons();
    } catch (err) {
        console.error('Error loading dashboard data:', err);
    }
}

function renderAssessment(data) {
    const bannerContainer = document.getElementById('alert-banner-container');
    const riskLevel = data.risk_level;
    const normalizedRiskClass = riskLevel.replace(' ', '-');

    const changes = data.detected_changes;
    const milkChange = changes['Milk Production'] || '--';
    const weightChange = changes['Weight'] || '--';
    const vacChange = changes['Vaccination'] || '--';

    // Render Alert Banner matching the exact Prompt specification
    bannerContainer.innerHTML = `
        <div class="alert-box ${normalizedRiskClass}">
            <div class="alert-banner-header">
                <div>
                    <h2>${data.alert_title}</h2>
                    <p style="font-size: 0.9rem; opacity: 0.9;">Cattle: <strong>${data.cattle_name} (${data.cattle_id})</strong> • Farm: <strong>${data.farm_id}</strong></p>
                </div>
                <div class="badge" style="background: rgba(0,0,0,0.1); font-size: 1rem;">
                    ${riskLevel} (Score: ${data.health_score}/100)
                </div>
            </div>

            <div class="alert-changes-grid">
                <div class="change-item">
                    <span class="label">Milk Production</span>
                    <div class="value" style="color: var(--milk-color);">${milkChange}</div>
                </div>
                <div class="change-item">
                    <span class="label">Body Weight</span>
                    <div class="value" style="color: var(--weight-color);">${weightChange}</div>
                </div>
                <div class="change-item">
                    <span class="label">Vaccination Status</span>
                    <div class="value" style="color: var(--vac-color);">${vacChange}</div>
                </div>
            </div>
        </div>
    `;

    // Render KPI Cards
    const feat = data.features || {};
    document.getElementById('kpi-milk-val').textContent = `${feat.current_milk || '--'} L`;
    const milkTrend = feat.delta_milk_pct_7d !== undefined ? `${feat.delta_milk_pct_7d > 0 ? '+' : ''}${feat.delta_milk_pct_7d}%` : '--';
    document.getElementById('kpi-milk-sub').textContent = `7-day Change: ${milkTrend}`;

    document.getElementById('kpi-weight-val').textContent = `${feat.current_weight || '--'} kg`;
    const weightTrend = feat.delta_weight_pct_7d !== undefined ? `${feat.delta_weight_pct_7d > 0 ? '+' : ''}${feat.delta_weight_pct_7d}%` : '--';
    document.getElementById('kpi-weight-sub').textContent = `7-day Change: ${weightTrend}`;

    document.getElementById('kpi-vaccine-val').textContent = feat.vaccine_status || '--';
    document.getElementById('kpi-vaccine-sub').textContent = feat.vaccine_status === 'Due Soon' ? 'Booster due in < 7 days' : (feat.vaccine_status === 'Overdue' ? 'Immunity expired' : 'Full Protection');

    document.getElementById('kpi-score-val').textContent = `${data.health_score} / 100`;
    document.getElementById('kpi-score-level').textContent = `Status: ${riskLevel}`;

    // Render Observations & Actions
    document.getElementById('ai-observations-content').textContent = data.ai_observation;
    document.getElementById('ai-actions-content').textContent = data.recommended_action;
    document.getElementById('disclaimer-text').textContent = data.disclaimer;

    // Render Hypotheses
    const hypList = document.getElementById('hypotheses-list');
    hypList.innerHTML = '';
    if (data.possible_reasons && data.possible_reasons.length > 0) {
        data.possible_reasons.forEach(item => {
            const li = document.createElement('li');
            li.textContent = item;
            hypList.appendChild(li);
        });
    } else {
        const li = document.createElement('li');
        li.textContent = 'None detected (Biological parameters normal).';
        hypList.appendChild(li);
    }
}

function renderChart(timeline) {
    const ctx = document.getElementById('healthTimelineChart').getContext('2d');

    const labels = timeline.map(t => {
        const d = new Date(t.date);
        return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
    });

    const milkData = timeline.map(t => t.milk);
    const weightData = timeline.map(t => t.weight);

    if (chartInstance) {
        chartInstance.destroy();
    }

    chartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Milk Production (Liters)',
                    data: milkData,
                    borderColor: '#3B82F6',
                    backgroundColor: 'rgba(59, 130, 246, 0.08)',
                    borderWidth: 2.5,
                    fill: true,
                    tension: 0.3,
                    yAxisID: 'yMilk',
                    pointRadius: 3,
                    pointHoverRadius: 6
                },
                {
                    label: 'Body Weight (kg)',
                    data: weightData,
                    borderColor: '#10B981',
                    backgroundColor: 'transparent',
                    borderWidth: 2.5,
                    borderDash: [4, 4],
                    tension: 0.3,
                    yAxisID: 'yWeight',
                    pointRadius: 3,
                    pointHoverRadius: 6
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false,
            },
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: '#1E293B',
                    padding: 10,
                    callbacks: {
                        afterBody: (context) => {
                            const dataIndex = context[0].dataIndex;
                            const tItem = timeline[dataIndex];
                            if (tItem.vaccine) {
                                return `\n[Vaccination]: ${tItem.vaccine}`;
                            }
                            return '';
                        }
                    }
                }
            },
            scales: {
                x: {
                    grid: { color: 'rgba(0, 0, 0, 0.04)' },
                    ticks: { maxTicksLimit: 12 }
                },
                yMilk: {
                    type: 'linear',
                    display: true,
                    position: 'left',
                    title: { display: true, text: 'Milk Yield (Liters)', color: '#3B82F6', font: { weight: 'bold' } },
                    grid: { color: 'rgba(0, 0, 0, 0.05)' },
                    min: 0,
                    suggestedMax: 22
                },
                yWeight: {
                    type: 'linear',
                    display: true,
                    position: 'right',
                    title: { display: true, text: 'Body Weight (kg)', color: '#10B981', font: { weight: 'bold' } },
                    grid: { drawOnChartArea: false }, // avoid overlapping grid lines
                    min: 350,
                    suggestedMax: 500
                }
            }
        }
    });
}
