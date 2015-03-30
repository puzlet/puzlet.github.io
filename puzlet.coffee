###

Puzlet Bootstrap

Handles these Puzlet hosts:

1. org.github.io - GitHub organization.  Everything loaded from GitHub (loader is //puzlet.org/puzlet/js/loader.js)
2. puzlet.org - Known custom domain (can set others here).  As above.
3. custom-domain.org - Unknown custom domain.  Requires /CNAME and /owner.json.  Otherwise, as above.
4. localhost:port/path/repo - Local development.  Usually path=org.  Requires /puzlet.json.  Should have empty /CNAME to avoid GET errors.
5. deployment.com/path/repo - Deployment server.  Same as 4, but path likely not org.

puzlet.json tells Puzlet the local folder coresponding to a GitHub organization (e.g., for /org/repo/file.ext in resources.coffee).
If the organization/folder does not exist in puzlet.json, Puzlet will use GitHub to get an organization's resources.

If the *current* blab's organization is not in puzlet.json, Puzlet will try to use the blab's URL to determine the organization name:
host.com/path/org/repo

For all host types, this bootstrap sets $blab.gitHub, which contains GitHub-related information:
owner, repo, host, local config.

jQuery is loaded.

###

puzletOrg = "http://puzlet.org"
loaderPath = "/puzlet/js/loader.js"  # repo/folder/file

gitHubIo = "org.github.io"

# Register known custom domain names for GitHub organizations.
# This is faster than checking CNAME and owner.json files.
knownGitHubOrgDomains = [
  {domain: "puzlet.org", org: "puzlet"}
]

cnameFile = "/CNAME"
ownerFile = "/owner.json"
configFile = "/puzlet.json"

jQuerySource = "//ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js"

window.console = {} unless window.console?
window.console.log = (->) unless window.console.log?

console.log "Puzlet bootstrap"

# Script loader
loadScript = (url, cache=false, onLoad=(->), onError=(->)) ->
  script = document.createElement "script"
  #script.setAttribute "type", "text/javascript"
  script.setAttribute "src", url + (if cache then "" else "?t=#{Date.now()}")
  script.onload = onLoad
  script.onerror = onError
  document.head.appendChild script

# Ajax file loader
loadFile = (file, callback) ->
  $.ajax
      url: file + "?t=#{Date.now()}"  # No cache
      error: -> callback null
      success: (data) -> callback(data)

# Check whether host is GitHub organization/owner.
# org.github.io or puzlet.org or other known hostname.
# If that fails, see if CNAME contents matches hostname.
# Determine owner/repo.
getGitHub = (callback) ->
  
  # Initial settings (overridden below)
  gitHub =
    isGitHubHosted: false
    localConfig: null
    owner: null
    repo: null
  
  a = document.createElement "a"
  a.href = window.location.href
  hostname = a.hostname
  pathname = a.pathname
  
  host = hostname.split "."
  gh = gitHubIo.split "."
  path = pathname.split "/"
  
  # Repo is always last part of URL path
  gitHub.repo = path[-2..-2][0]
  
  # Check if org.github.io.
  isGitHubIo = host.length is 3 and host[1] is gh[1] and host[2] is gh[2]
  if isGitHubIo
    gitHub.isGitHubHosted = true
    gitHub.owner = host[0]
    callback(gitHub)
    return
  
  # Check if known custom domain.
  customDomains = knownGitHubOrgDomains.filter((d) -> hostname is d.domain)
  if customDomains.length>0
    gitHub.isGitHubHosted = true
    gitHub.owner = customDomains[0].org
    callback(gitHub)
    return
  
  getLocalConfig = ->
    loadFile configFile, (config) ->
      gitHub.localConfig = config
      if config?.orgs?
        # Search for owner/org in config file.  TODO: try orgRoot as well.
        for org, p of config.orgs
          if pathname.indexOf(p) is 0
              gitHub.owner = org
              break 
      gitHub.owner ?= if path.length>2 then path[-3..-3][0] else null  # Default owner from path (path/owner/repo/)
      callback(gitHub)
    
  # Check if another custom domain by inspecting CNAME file.
  $.ajax
      
      url: cnameFile
      
      error: ->
        # No CNAME file => assume localhost/deployment
        gitHub.isGitHubHosted = false
        getLocalConfig()
      
      success: (data) ->
        
        ghHosted = (data is hostname)
        gitHub.isGitHubHosted = ghHosted  # Contents of CNAME must match host name.
        
        if ghHosted
          # If (unknown) custom domain, get owner from owner.json.
          # No way to determine owner otherwise.
          loadFile ownerFile, (owner) ->
            gitHub.owner = owner
            callback(gitHub)
        else
          # CNAME host does not match => assume localhost/deployment.
          getLocalConfig()

window.$blab = {}  # Exported interface.

# Sequence: load jQuery; fetch GitHub data; load puzlet.json (if not GitHub); load Puzlet.
jQueryCache = true
loadScript jQuerySource, jQueryCache, ->
  
  getGitHub (gitHub) ->
    
    $blab.gitHub = gitHub
    ghHosted = gitHub.isGitHubHosted
    console.log "Host: "+(if ghHosted then "GitHub" else "local/deployment")
    
    if ghHosted
      loaderUrl = puzletOrg + loaderPath
    else
      localPuzlet = gitHub.localConfig?.orgs?.puzlet  # Must have orgs.puzlet set to use local Puzlet.
      loaderUrl = (localPuzlet ? puzletOrg) + loaderPath
    
    console.log "Load Puzlet (#{loaderUrl})"
    loadScript(loaderUrl)
