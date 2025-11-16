import Chart from 'chart.js/auto';

const ChartHook = {
  mounted() {
    this.renderChart();
  },
  updated() {
    this.renderChart();
  },
  renderChart() {
    const ctx = this.el.querySelector('canvas');
    if (!ctx) return;
    const chartData = JSON.parse(this.el.dataset.chart);
    if (this.chart) this.chart.destroy();
    this.chart = new Chart(ctx, {
      type: 'line',
      data: chartData,
      options: {
        responsive: true,
        plugins: {
          legend: { display: true },
          title: { display: true, text: 'Credits & Debits Over Time' }
        },
        scales: {
          x: { title: { display: true, text: 'Date' } },
          y: { title: { display: true, text: 'Amount' } }
        }
      }
    });
  }
};

export default ChartHook;
