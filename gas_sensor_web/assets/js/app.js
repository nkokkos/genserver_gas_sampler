// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
///import {hooks as colocatedHooks} from "phoenix-colocated/gas_sensor_web"

import topbar from "../vendor/topbar"
import Chart from "chart.js/auto";

let Hooks = {}

// first hook for CO and Temperature 
Hooks.SensorChart = {
  // Runs once when the page/canvas loads
  mounted() {
    const ctx = this.el.getContext('2d');
    const data = JSON.parse(this.el.dataset.history);

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => d.time),
        datasets: [
          {
	    label: 'CO (PPM)',
            data: data.map(d => d.co_ppm),
            borderColor: '#ef4444',
            backgroundColor: 'rgba(239, 68, 68, 0.1)',
            yAxisID: 'y',
            borderWidth: 3,
            tension: 0.4,
            fill: true,
            min: 0,
            suggestedMax: 150 // Adjusts if data goes higher
          },
          {
            label: 'Temp (°C)',
            data: data.map(d => d.temperature),
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            yAxisID: 'y1',
            borderWidth: 3,
            tension: 0.4,
            fill: true,
            min: 0,
	    suggestedMax: 80
          }
        ]
      },
      options: {
	animation: false,
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: { type: 'linear', position: 'left', title: { display: true, text: 'PPM' } },
          y1: { type: 'linear', position: 'right', grid: { drawOnChartArea: false } }
        }
      }
    });
  },

  // THIS IS THE UPDATED FUNCTION
  // It runs every 5 seconds when the server sends new @history
  updated() {
    const data = JSON.parse(this.el.dataset.history);
    
    // Update labels (time)
    this.chart.data.labels = data.map(d => d.time);
    
    // Update both lines
    this.chart.data.datasets[0].data = data.map(d => d.co_ppm);
    this.chart.data.datasets[1].data = data.map(d => d.temperature);
    
    // 'none' prevents the chart from bouncing/animating on every tick
    this.chart.update('none');
  }
}

Hooks.SensorChart_volts = {
  // Runs once when the page/canvas loads
  mounted() {
    const ctx = this.el.getContext('2d');
    const data = JSON.parse(this.el.dataset.historyVolts);

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => d.time),
        datasets: [
          {
            label: 'CO (PPM)',
            data: data.map(d => d.co_ppm),
            borderColor: '#ef4444',
            backgroundColor: 'rgba(239, 68, 68, 0.1)',
            yAxisID: 'y',
            borderWidth: 3,
            tension: 0.4,
            fill: true
          },
          {
            label: 'Vsensor Volts',
            data: data.map(d => d.vsensor),
            borderColor: '#3b82f6',
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            yAxisID: 'y1',
            borderWidth: 3,
            tension: 0.4,
            fill: true
          }
        ]
      },
      options: {
	animation: false,
        responsive: true,
        maintainAspectRatio: false,
	scales: {
          y: { 
            type: 'linear', 
            beginAtZero: true,
            title: { display: true, text: 'Value' } 
          }
        //scales:
	//{
          // Removed y1 axis
        //  y: { 
        //    type: 'linear', 
        //    position: 'left', 
        //    beginAtZero: true,
        //    title: { display: true, text: 'Consolidated Scale' } 
        //  }
        }
        //scales: {
        //  y: { type: 'linear', position: 'left', title: { display: true, text: 'PPM' } },
        //  y1: { type: 'linear', position: 'right', grid: { drawOnChartArea: false } }
        //}
      }
    });
  },

  // THIS IS THE UPDATED FUNCTION
  // It runs every 5 seconds when the server sends new @history
  updated() {
    const data = JSON.parse(this.el.dataset.historyVolts);
    
    // Update labels (time)
    this.chart.data.labels = data.map(d => d.time);
    
    // Update both lines
    this.chart.data.datasets[0].data = data.map(d => d.co_ppm);
    this.chart.data.datasets[1].data = data.map(d => d.vsensor);
    
    // 'none' prevents the chart from bouncing/animating on every tick
    this.chart.update('none');
  }
};

Hooks.SensorChartHistory_2Hours = {
  // Runs once when the page/canvas loads
  mounted() {
    const ctx = this.el.getContext('2d');
    const data = JSON.parse(this.el.dataset.historyHours2);

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.map(d => d.time),
        datasets: [
          {
            label: 'CO (PPM)',
            data: data.map(d => d.co_ppm),
            borderColor: '#ef4444', // Red
            backgroundColor: 'rgba(239, 68, 68, 0.1)',
            yAxisID: 'y',
            borderWidth: 3,
            tension: 0.4,
            fill: true
          },
          {
            label: 'Temperature',
            data: data.map(d => d.temperature_c),
            borderColor: '#3b82f6', // Blue
            backgroundColor: 'rgba(59, 130, 246, 0.1)',
            yAxisID: 'y1',
            borderWidth: 3,
            tension: 0.4,
            fill: true
          },
          {
            label: 'Humidity',
            data: data.map(d => d.humidity_rh),
            borderColor: '#10b981', // Green (Distinguishable from Temp)
            backgroundColor: 'rgba(16, 185, 129, 0.1)',
            yAxisID: 'y1',
            borderWidth: 3,
            tension: 0.4,
            fill: true
          } 
        ]
      },
      options: {
	animation: false,
        responsive: true,
        maintainAspectRatio: false,
	scales: {
          y: { 
            type: 'linear', 
            beginAtZero: true,
            position: 'left',
            title: { display: true, text: 'CO ppm' } 
          },
          y1: {
            type: 'linear',
            display: true,
            position: 'right',
            title: { display: true, text: 'Temp / Humidity' },
            // Grid lines on the right axis can make the chart look messy
            grid: { drawOnChartArea: false } 
          }
        //scales:
	//{
          // Removed y1 axis
        //  y: { 
        //    type: 'linear', 
        //    position: 'left', 
        //    beginAtZero: true,
        //    title: { display: true, text: 'Consolidated Scale' } 
        //  }
        }
        //scales: {
        //  y: { type: 'linear', position: 'left', title: { display: true, text: 'PPM' } },
        //  y1: { type: 'linear', position: 'right', grid: { drawOnChartArea: false } }
        //}
      }
    });
  },

  // THIS IS THE UPDATED FUNCTION
  // It runs every 5 seconds when the server sends new @history
  updated() {
    const data = JSON.parse(this.el.dataset.historyHours2);
    
    // Update labels (time)
    this.chart.data.labels = data.map(d => d.time);
    
    // Update both lines
    this.chart.data.datasets[0].data = data.map(d => d.co_ppm);
    this.chart.data.datasets[1].data = data.map(d => d.temperature_c);
    this.chart.data.datasets[2].data = data.map(d => d.humidity_rh);
    // 'none' prevents the chart from bouncing/animating on every tick
    this.chart.update('none');
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks // This contains the SensorChart logic
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

