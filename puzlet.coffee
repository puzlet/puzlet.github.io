###
Puzlet Bootstrap
###

console.log "Puzlet bootstrap"

window.console = {} unless window.console?
window.console.log = (->) unless window.console.log?

url = window.location.href

a = document.createElement "a"
a.href = url

# URL components
host = a.hostname
path = a.pathname
search = a.search 

# Decompose into parts
hostParts = host.split "."
pathParts = if path then path.split "/" else []
hasPath = pathParts.length

# Resource host type
isLocalHost = host is "localhost"
isPuzlet = host is "puzlet.org"

console.log "host/path/search", host, path, search




