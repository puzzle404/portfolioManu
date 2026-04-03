import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js/auto"

// Inline plugin to draw percentage labels on charts (no external dependency)
const percentLabelsPlugin = {
  id: "percentLabels",
  afterDatasetsDraw(chart) {
    const config = chart.config.options.plugins.percentLabels
    if (!config || config.display === false) return

    const { ctx } = chart
    ctx.save()
    ctx.font = `bold ${config.fontSize || 11}px sans-serif`
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"

    chart.data.datasets.forEach((dataset, dsIndex) => {
      const meta = chart.getDatasetMeta(dsIndex)
      meta.data.forEach((element, index) => {
        const label = config.formatter(dataset.data[index], { dataIndex: index, datasetIndex: dsIndex })
        if (!label) return

        ctx.fillStyle = config.color || "#fff"

        if (chart.config.type === "doughnut") {
          // Position label in the middle of the arc
          const arc = element
          const centerX = (chart.chartArea.left + chart.chartArea.right) / 2
          const centerY = (chart.chartArea.top + chart.chartArea.bottom) / 2
          const innerRadius = arc.innerRadius
          const outerRadius = arc.outerRadius
          const midRadius = (innerRadius + outerRadius) / 2
          const startAngle = arc.startAngle
          const endAngle = arc.endAngle
          const midAngle = (startAngle + endAngle) / 2
          const x = centerX + Math.cos(midAngle) * midRadius
          const y = centerY + Math.sin(midAngle) * midRadius
          ctx.fillText(label, x, y)
        } else {
          // Bar charts: position above or inside the bar
          const anchor = config.anchor || "center"
          let x = element.x
          let y
          if (anchor === "end") {
            y = element.y - 8
          } else {
            // center of bar
            y = element.y + (element.base - element.y) / 2
          }
          ctx.fillText(label, x, y)
        }
      })
    })
    ctx.restore()
  }
}

export default class extends Controller {
  static targets = ["categoryChart", "categoryLegend", "dailyChart", "monthlyChart", "fixedVarChart"]
  static values = {
    byCategory: Array,
    daily: Array,
    monthly: Array,
    fixedVariable: Array
  }

  connect() {
    Chart.register(percentLabelsPlugin)
    this.charts = []

    Chart.defaults.color = "rgba(255, 255, 255, 0.5)"
    Chart.defaults.borderColor = "rgba(255, 255, 255, 0.06)"

    if (this.hasCategoryChartTarget && this.byCategoryValue.length > 0) this.renderCategoryChart()
    if (this.hasDailyChartTarget && this.dailyValue.length > 0) this.renderDailyChart()
    if (this.hasMonthlyChartTarget && this.monthlyValue.length > 0) this.renderMonthlyChart()
    if (this.hasFixedVarChartTarget && this.fixedVariableValue.length > 0) this.renderFixedVarChart()
  }

  disconnect() {
    this.charts.forEach(c => c.destroy())
  }

  renderCategoryChart() {
    const data = this.byCategoryValue
    const total = data.reduce((s, d) => s + d.total, 0)

    const chart = new Chart(this.categoryChartTarget, {
      type: "doughnut",
      data: {
        labels: data.map(d => d.name),
        datasets: [{
          data: data.map(d => d.total),
          backgroundColor: data.map(d => d.color),
          borderWidth: 0,
          hoverBorderWidth: 2,
          hoverBorderColor: "#fff"
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "65%",
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const pct = ((ctx.parsed / total) * 100).toFixed(1)
                return ` $${this.formatNumber(ctx.parsed)} (${pct}%)`
              }
            }
          },
          percentLabels: {
            color: "#fff",
            fontSize: 11,
            formatter: (value) => {
              const pct = ((value / total) * 100).toFixed(1)
              return pct >= 5 ? `${pct}%` : ""
            }
          }
        }
      }
    })
    this.charts.push(chart)

    if (this.hasCategoryLegendTarget) {
      this.categoryLegendTarget.innerHTML = data.map(d => {
        const pct = ((d.total / total) * 100).toFixed(1)
        return `<div class="finance-legend-item">
          <span class="finance-legend-dot" style="background:${d.color}"></span>
          <span class="finance-legend-label">${d.name}</span>
          <span class="finance-legend-value">$${this.formatNumber(d.total)}</span>
          <span class="finance-legend-pct">${pct}%</span>
        </div>`
      }).join("")
    }
  }

  renderDailyChart() {
    const data = this.dailyValue
    const chart = new Chart(this.dailyChartTarget, {
      type: "line",
      data: {
        labels: data.map(d => d.date),
        datasets: [{
          data: data.map(d => d.total),
          borderColor: "rgba(17, 186, 200, 0.8)",
          backgroundColor: "rgba(17, 186, 200, 0.1)",
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointRadius: 0,
          pointHitRadius: 10,
          pointHoverRadius: 4,
          pointHoverBackgroundColor: "#11bac8"
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          percentLabels: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => ` Acumulado: $${this.formatNumber(ctx.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            ticks: { maxTicksLimit: 8, font: { size: 10 } },
            grid: { display: false }
          },
          y: {
            ticks: {
              font: { size: 10 },
              callback: (v) => `$${this.formatCompact(v)}`
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderMonthlyChart() {
    const data = this.monthlyValue
    const totals = data.map(d => d.total)
    const chart = new Chart(this.monthlyChartTarget, {
      type: "bar",
      data: {
        labels: data.map(d => d.month),
        datasets: [{
          data: totals,
          backgroundColor: "rgba(17, 86, 93, 0.6)",
          hoverBackgroundColor: "rgba(17, 186, 200, 0.7)",
          borderRadius: 6,
          borderSkipped: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => ` Total: $${this.formatNumber(ctx.parsed.y)}`
            }
          },
          percentLabels: {
            anchor: "end",
            color: "rgba(255, 255, 255, 0.6)",
            fontSize: 10,
            formatter: (value, ctx) => {
              if (ctx.dataIndex === 0) return `$${this.formatCompact(value)}`
              const prev = totals[ctx.dataIndex - 1]
              if (!prev || prev === 0) return `$${this.formatCompact(value)}`
              const change = (((value - prev) / prev) * 100).toFixed(0)
              const sign = change > 0 ? "+" : ""
              return `${sign}${change}%`
            }
          }
        },
        scales: {
          x: {
            ticks: { font: { size: 11 } },
            grid: { display: false }
          },
          y: {
            ticks: {
              font: { size: 10 },
              callback: (v) => `$${this.formatCompact(v)}`
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  renderFixedVarChart() {
    const data = this.fixedVariableValue
    const monthTotals = data.map(d => d.fijo + d.variable)
    const chart = new Chart(this.fixedVarChartTarget, {
      type: "bar",
      data: {
        labels: data.map(d => d.month),
        datasets: [
          {
            label: "Fijo",
            data: data.map(d => d.fijo),
            backgroundColor: "rgba(99, 102, 241, 0.7)",
            hoverBackgroundColor: "rgba(99, 102, 241, 0.9)",
            borderRadius: 4,
            borderSkipped: false
          },
          {
            label: "Variable",
            data: data.map(d => d.variable),
            backgroundColor: "rgba(249, 115, 22, 0.7)",
            hoverBackgroundColor: "rgba(249, 115, 22, 0.9)",
            borderRadius: 4,
            borderSkipped: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "top",
            labels: { boxWidth: 12, padding: 16, font: { size: 11 } }
          },
          tooltip: {
            callbacks: {
              label: (ctx) => ` ${ctx.dataset.label}: $${this.formatNumber(ctx.parsed.y)}`
            }
          },
          percentLabels: {
            color: "#fff",
            fontSize: 10,
            formatter: (value, ctx) => {
              const total = monthTotals[ctx.dataIndex]
              if (!total || total === 0) return ""
              const pct = ((value / total) * 100).toFixed(0)
              return pct >= 5 ? `${pct}%` : ""
            }
          }
        },
        scales: {
          x: {
            stacked: true,
            ticks: { font: { size: 11 } },
            grid: { display: false }
          },
          y: {
            stacked: true,
            ticks: {
              font: { size: 10 },
              callback: (v) => `$${this.formatCompact(v)}`
            }
          }
        }
      }
    })
    this.charts.push(chart)
  }

  formatNumber(n) {
    return new Intl.NumberFormat("es-AR", { maximumFractionDigits: 0 }).format(n)
  }

  formatCompact(n) {
    if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`
    if (n >= 1000) return `${(n / 1000).toFixed(0)}k`
    return n.toString()
  }
}
