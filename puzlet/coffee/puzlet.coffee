$("#app_container").append "Test"

console.log "window.location", window.location

$.getJSON("/compressive_sensing_introduction/test.json", (data) ->
  console.log("test.json", data)
)