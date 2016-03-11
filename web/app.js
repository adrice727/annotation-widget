'use strict';

/*
 * Express Dependencies
 */
var express = require('express');
var https = require('https');
var fs = require('fs');
var app = express();
var port = 3000;
var bodyParser = require('body-parser');

// Set up https
var credentials = {
  key : fs.readFileSync('./ssl/key.pem'),
  cert: fs.readFileSync('./ssl/cert.pem')
};
var server = https.createServer(credentials, app);

// For gzip compression
app.use(express.static(__dirname + '/'));

/*
 * Config for Production and Development
 */
// if (process.env.NODE_ENV === 'production') {
//     // Set the default layout and locate layouts and partials
//     app.engine('handlebars', exphbs({
//         defaultLayout: 'main',
//         layoutsDir: 'dist/views/layouts/',
//         partialsDir: 'dist/views/partials/',
//         whitelabelDir: 'dist/views/whitelabel/'
//     }));
//
//     // Locate the views
//     app.set('views', __dirname + '/views');
//
//     // Locate the assets
//     app.use(express.static(__dirname + '/assets'));
//
// } else {
//     app.engine('handlebars', exphbs({
//         // Default Layout and locate layouts and partials
//         defaultLayout: 'main',
//         layoutsDir: 'views/layouts/',
//         partialsDir: 'views/partials/',
//         whitelabelDir: 'views/whitelabel/'
//     }));
//
//     // Locate the views
//     app.set('views', __dirname + '/views');
//
//     // Locate the assets
//     app.use(express.static(__dirname + '/assets'));
// }
//
// // Set Handlebars
// app.set('view engine', 'handlebars');
app.use(bodyParser.urlencoded());

/*
 * Routes
 */

// Index Page
app.get('/', function(request, response, next) {
    response.render('index.html');
});

/*
 * Start it up
 */
// app.listen(process.env.PORT || port);
server.listen(process.env.PORT || port);
console.log('Express started on port ' + port);
