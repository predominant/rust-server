var RconCommon = function(){};

RconCommon.prototype.createPacket = function(command, id, name) {
    if (typeof id === "undefined") id = -1;
    if (typeof name === "undefined") name = "WebRcon";
    return JSON.stringify({
		Identifier: id,
		Message: command,
		Name: name
	});
};

module.exports = new RconCommon();
