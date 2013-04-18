// Wraps Tizen interface "NFCAdapter" that resides in Tizen module "NFC".

define(['Ti/_/declare', 'Ti/_/Evented', 'Tizen/_/NFC/NFCTag', 'Tizen/_/NFC/NFCPeer'], function(declare, Evented, NFCTag, NFCPeer) {

	var adapter = declare(Evented, {

		constructor: function(args) {
			if (args.toString() === '[object NFCAdapter]') {
				// args is a native Tizen object; simply wrap it (take ownership of it)
				this._obj = args;
			} 
		},

		setPowered: function(state, callback) {
			return this._obj.setPowered(state, callback && function() {
				callback({
					success: true,
					code: 0
				});
			}, callback && function(e) {
				callback({
					success: false,
					error: e.type + ': ' + e.message,
					code: e.code
				});
			});
		},

		setTagListener: function(detectCallback, tagFilter) {

			return this._obj.setTagListener({
				onattach: function(nfcTag) {
					detectCallback.onattach(new NFCTag(nfcTag));
				},
				ondetach: function() {
					detectCallback.ondetach();
				}
			}, tagFilter);
		},

		setPeerListener: function(detectCallback) {
			return this._obj.setPeerListener({
				onattach: function(nfcPeer) {
					detectCallback.onattach(new NFCPeer(nfcPeer));
				},
				ondetach: function() {
					detectCallback.ondetach();
				}
			});
		},

		unsetTagListener: function() {
			return this._obj.unsetTagListener();
		},

		unsetPeerListener: function() {
			return this._obj.unsetPeerListener();
		},

		getCachedMessage: function() {
			return this._obj.getCachedMessage();
		},

		constants: {
			powered: {
				get: function() {
					return this._obj.powered;
				}
			}
		}

	});

	// Initialize declaredClass, so that toString() works properly on such objects.
	// Correct operation of toString() is required for proper wrapping and automated testing.
	adapter.prototype.declaredClass = 'Tizen.NFC.NFCAdapter';
	return adapter;
});
