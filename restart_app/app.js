#!/usr/bin/env node

var debug = false;
var request = require('request');
var rcon = require('../rcon');
var isRestarting = false;
var now = Math.floor(new Date() / 1000);
var timeout = debug ? (1000 * 60) : (1000 * 60) * 30;
var updateCheckInterval = debug ? (1000 * 5) : (1000 * 60) * 5;

var clientUpdateRequest = {
	url: 'https://whenisupdate.com/api.json',
	headers: {
		Referer: 'rust-docker-server'
	},
	timeout: 10000
};

// Timeout after 30 minutes and restart
setTimeout(function() {
	console.log("Timeout exceeded, forcing a restart");
	restart();
}, timeout);

// Start checking for client updates
checkForClientUpdate();

function checkForClientUpdate() {
	if (isRestarting) {
		if (debug) console.log("We're restarting, skipping client update check..");
		return;
	}

	console.log("Checking if a client update is available..");
	request(clientUpdateRequest, function(error, response, body) {
		if (!error && response.statusCode == 200) {
		    var latest = JSON.parse(body).latest;
		    if (latest !== undefined && latest.length > 0) {
		    	if (latest >= now) {
		    		console.log("Client update is out, forcing a restart");
		    		restart();
		    		return;
		    	}
		    }
		    if (debug) console.log("Client update not out yet..");
	  	} else {
	  		if (debug) console.log("Error: " + error);
	  	}

	  	// Keep checking for client updates every 5 minutes
	  	setTimeout(function() {
			checkForClientUpdate();
		}, updateCheckInterval);
	});
}

function sayRestartNotice(ws, s) {
	var sString = s + " minute" + (s > 1 ? "s" : "");
	ws.send(rcon.createPacket("say NOTICE: We're updating the server in <color=orange>" + sString + "</color>, so get to a safe spot!"));
}

function restart() {
	if (debug) console.log("Restarting..");
	if (isRestarting) {
		if (debug) console.log("We're already restarting..");
		return;
	}
	isRestarting = true;

	var serverHostname = 'localhost';
	var serverPort = process.env.RUST_RCON_PORT;
	var serverPassword = process.env.RUST_RCON_PASSWORD;

	var WebSocket = require('ws');
	var ws = new WebSocket("ws://" + serverHostname + ":" + serverPort + "/" + serverPassword);
	ws.on('open', function open() {
		setTimeout(function() {
			sayRestartNotice(ws, 5);
			setTimeout(function() {
				sayRestartNotice(ws, 4);
				setTimeout(function() {
					sayRestartNotice(ws, 3);
					setTimeout(function() {
						sayRestartNotice(ws, 2);
						setTimeout(function() {
							sayRestartNotice(ws, 1);
							setTimeout(function() {
								ws.send(rcon.createPacket("global.kickall <color=orange>Updating/Restarting</color>"));
								setTimeout(function() {
									ws.send(rcon.createPacket("quit"));
									//ws.send(rcon.createPacket("restart 60")); // NOTE: Don't use restart, because that doesn't actually restart the container!
									setTimeout(function() {
										ws.close(1000);

										// After 2 minutes, if the server's still running, forcibly shut it down
										setTimeout(function() {
											var fs = require('fs');
											fs.unlinkSync('/tmp/restart_app.lock');

											var child_process = require('child_process');
											child_process.execSync('kill -s 2 $(pidof bash)');
										}, 1000 * 60 * 2);
									}, 1000);
								}, 1000);
							}, 1000 * 60);
						}, 1000 * 60);
					}, 1000 * 60);
				}, 1000 * 60);
			}, 1000 * 60);
		}, 1000);
	});
}
