#!./node_modules/coffee-script/bin/coffee

###############################################################################
# Dependencies #
################

fs = require 'fs'
request = require 'request'
optimist = require 'optimist'

###############################################################################
# Config #
##########

opts = optimist.usage('Spider.io Alexa/Ghostery challenge')
       .options('t',
         alias: 'timeout'
         default: 30
         describe: 'Seconds to wait for page')
       .options('n',
         alias: 'num'
         default: 100000
         describe: 'Number of sites to use')
       .options('p',
         alias: 'pending'
         default: 25
         describe: 'Maximum number of pending requests')
       .options('i',
         alias: 'interval'
         default: 10
         describe: 'Seconds between updates')
       .options('a',
         alias: 'agent'
         default: 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/535.20 (KHTML, like Gecko) Chrome/19.0.1036.7 Safari/535.20'
         describe: 'User-Agent to use')
       .options('r',
         alias: 'rate'
         default: 10
         describe: 'Target requests per second')
       .options('b',
         alias: 'bugs'
         default: './data/bugs.json'
         describe: 'JSON file containing Ghostery bugs')
       .options('s',
         alias: 'sites'
         default: './data/top-1m.csv'
         describe: 'CSV file  containing ranked sites')
       .options('f',
         alias: 'failures'
         default: './results/failures.csv'
         describe: 'File to OVERWRITE with log failures')
       .options('o',
         alias: 'output'
         default: './results/matches.index'
         describe: 'File to APPEND output results')
       .options('k',
         alias: 'skip'
         default: 0
         describe: 'Number of sites to skip in input')
       .options('h',
         alias: 'help'
         default: false
         describe: 'Display help')
       .check () ->
         return true
argv = opts.argv

if argv.h
  opts.showHelp()
  process.exit()

userAgent = argv.a
maxRequestRate = argv.r
maxPending = argv.p
maxSites = argv.n
updateInterval = argv.i
timeout = argv.t
skip = argv.k

bugsFile  = argv.b
sitesFile = argv.s

resultsFile = argv.o
failuresFile = argv.f

###############################################################################
# Initialisation #
##################

# Read in the bugs file
bugsStr = fs.readFileSync bugsFile, 'utf8'
bugs = (JSON.parse bugsStr).bugs
bug.regex = new RegExp bug.pattern for bug in bugs

# Read in the sites file
sitesStr = fs.readFileSync sitesFile, 'utf8'
lines = sitesStr.split '\n'
lines = (line for line in lines when line.length > 2)
lines = lines.slice skip, (maxSites+skip)
sites = (line.split ',' for line in lines)

maxSites = sites.length

fdResults = fs.openSync resultsFile, 'a'    # the results file
fdFailures = fs.openSync failuresFile, 'w'  # the failures file

###############################################################################
# Utilities #
#############

#
# Retrieve a site's rank and address from a given index.
#
getSiteInfo = (siteIndex) ->
  siteRank = sites[siteIndex][0]
  site = sites[siteIndex][1]
  return [siteRank, site]

#
# Log a failure to disk and stderr.
#
nFailures = 0
logFailure = (siteIndex, reason) ->
  ++nFailures
  [siteRank, site] = getSiteInfo siteIndex
  fs.writeSync fdFailures, "#{siteRank},#{site},#{reason}\n"

#
# Log a match to disk.
#
logMatch = (siteIndex, bugId) ->
  [siteRank, site] = getSiteInfo siteIndex
  fs.writeSync fdResults, "#{siteRank},#{bugId}\n"

#
# Notify of completion, close files and cancel timeouts.
#
cleanUp = () ->
  console.log "COMPLETE: #{nComplete - nFailures} successful, #{nFailures} failures"
  fs.closeSync fdResults
  fs.closeSync fdFailures
  clearInterval intervalId
  clearInterval updateId
  process.exit()

#
# If not at full capacity, begin processing the next site.
#
siteIndex = 0
processNextSite = () ->
  if siteIndex >= maxSites      # no more sites to process
    clearInterval intervalId
  else
    if nPending < maxPending    # have spare capacity
      [siteRank, site] = getSiteInfo siteIndex
      processSite siteIndex++

#
# Display status update.
#
nTicks = 0
showUpdate = () ->
  ++nTicks
  successRate = Math.floor (nComplete-nFailures) / nComplete * 100
  requestRate = Math.floor (nComplete + nPending) / nTicks / updateInterval
  console.log "Total: #{nComplete+nPending}, Complete: #{nComplete}, Success: #{nComplete-nFailures}, Failed: #{nFailures}, Pending: #{nPending}, Success Rate: #{successRate}%, Rate: #{requestRate} req/sec"

#
# Create options structure for http requests.
#
createOptions = (siteIndex) ->
  [siteRank, site] = getSiteInfo siteIndex
  options =
    url: "http://#{site}/"
    agent: false
    jar: false
    encoding: 'utf8'
    maxRedirects: 10
    timeout: timeout * 1000
    headers:
      'Accept': 'text/html;q=0.9,*/*;q=0.8'
      'Accept-Charset': 'utf-8;q=0.7,*;q=0.3'
      'Accept-Language': 'en-GB,en-US;q=0.8,en;q=0.6'
      'Accept-Encoding': ''
      'User-Agent': userAgent
    siteIndex: siteIndex
  return options


###############################################################################
# Main routine #
################

#
# Make the request for a page then match it against the regexes.
# Log the results appropriately.
#
nComplete = 0
nPending = 0
pending = {}
processSite = (siteIndex) ->

  [siteRank, site] = getSiteInfo siteIndex
  pending[site] = true
  ++nPending
  options = createOptions siteIndex
  request options, (error, response, body) ->
    siteIndex = options.siteIndex
    ++nComplete
    delete pending[site]
    --nPending
    if error
      logFailure siteIndex, error
    else if response.statusCode != 200
      logFailure siteIndex, response.statusCode
    else if not body?
      logFailure siteIndex, 'NO BODY'
    else
      logMatch siteIndex, bug.id for bug in bugs when bug.regex.test body
      
    if nComplete is maxSites
      cleanUp()


###############################################################################
# Begin work #
##############

intervalId = setInterval processNextSite, (1000 / maxRequestRate) # Perform requests
updateId = setInterval showUpdate, (updateInterval * 1000)        # Display updates

