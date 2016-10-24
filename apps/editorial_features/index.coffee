express = require 'express'
routes = require './routes'

app = module.exports = express()
app.set 'views', "#{__dirname}/templates"
app.set 'view engine', 'jade'

app.get '/eoy-2016', routes.eoy
app.get '/test-app', routes.testApp
