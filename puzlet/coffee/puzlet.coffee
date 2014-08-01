$("#app_container").append "Test"

console.log "window.location", window.location

$.getJSON("/cs-intro/test.json", (data) ->
  console.log("test.json", data)
)