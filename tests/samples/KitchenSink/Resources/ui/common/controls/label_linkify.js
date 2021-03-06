function label_linkify() {
	var win = Ti.UI.createWindow();
	win.backgroundColor = 'white';
	
	var l = Ti.UI.createLabel({
		autoLink : Ti.UI.LINKIFY_ALL,
		left : 5, top : 5, right : 5, height : 100,
		backgroundColor : '#222',
		text : 'Contact\n test@test.com\n 817-555-5555\n http://bit.ly\n 444 Castro Street, Mountain View, CA'
	});
	win.add(l);
	
	var btnAll = Ti.UI.createButton({
		title : 'All', width: 150, height: 40,
		top : 110
	});
	btnAll.addEventListener('click', function(e) {
		l.autoLink = Ti.UI.LINKIFY_ALL;
	});
	win.add(btnAll);
	
	var btnEmail = Ti.UI.createButton({
		title : 'Email Addresses', width: 150, height: 40,
		top : 200
	});
	btnEmail.addEventListener('click', function(e) {
		l.autoLink = Ti.UI.LINKIFY_EMAIL_ADDRESSES;
	});
	win.add(btnEmail);
	
	var btnMap = Ti.UI.createButton({
		title : 'Map Addresses', width: 150, height: 40,
		top : 200
	});
	
	var btnNONE = Ti.UI.createButton({
		title : 'None', width: 150, height: 40,
		top : 155
	});
	
	btnNONE.addEventListener('click', function(){
		l.autoLink = Ti.UI.LINKIFY_NONE;
	});
	
	win.add(btnNONE);
	
	var btnPhone = Ti.UI.createButton({
		title : 'Phone Numbers', width: 150, height: 40,
		top : 245
	});
	btnPhone.addEventListener('click', function(e) {
		l.autoLink = Ti.UI.LINKIFY_PHONE_NUMBERS;
	});
	win.add(btnPhone);
	
	var btnWeb = Ti.UI.createButton({
		title : 'Web URLs', width: 150, height: 40,
		top : 290
	});
	btnWeb.addEventListener('click', function(e) {
		l.autoLink = Ti.UI.LINKIFY_WEB_URLS;
	});
	win.add(btnWeb);
	
	var ta = Ti.UI.createTextArea({
		left : 5, top : 335, right : 5, bottom : 5 
	});
	ta.addEventListener('return', function(e) {
		l.text = e.value;
	});
	win.add(ta);
	
	return win;
}

module.exports = label_linkify;
