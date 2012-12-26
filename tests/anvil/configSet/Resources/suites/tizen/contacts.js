/*
 * Appcelerator Titanium Mobile
 * Copyright (c) 2011-2012 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

module.exports = new function() {
	var finish;
	var valueOf;
	var reportError;
	var watcherId;
	var _addressbook = tizen.contact.getDefaultAddressBook();
	this.init = function(testUtils) {
		finish = testUtils.finish;
		valueOf = testUtils.valueOf;
		reportError = testUtils.reportError;
	}

	this.name = "contacts";
	this.tests = [
		{name: "getDefaultAddressBook"},
		{name: "getAddressBook"},
		{name: "getAddressBooks"},
		{name: "getAddressBookInvalid"},
		{name: "getContact"},
		{name: "getContactsBatch"},
		{name: "updateContact"},
		{name: "updateBatch"},
		{name: "removeContact"},
		{name: "removeBatch"},
		{name: "find"},
		{name: "getCategories"},
		{name: "addAddressBookChangeListener"},
		{name: "removeAddressbookChangeListener"},
		{name: "convertToString"},
		{name: "cloneContact"},
		{name: "contactName"},
		{name: "contactOrganization"},
		{name: "contactWebsite"},
		{name: "contactAnniversary"},
		{name: "contactAddress"},
		{name: "contactPhoneNumber"},
		{name: "contactEmailAddress"},
		{name: "contactBirthday"},
		{name: "contactPhoto"},
		{name: "contactNote"},
		{name: "isFavorite"},
		{name: "contactRingtoneURI"},
		{name: "contactLastUpdated"},
		{name: "contactAddressBookId"}
	]

	this.getDefaultAddressBook = function(testRun) {
		var addressbook = tizen.contact.getDefaultAddressBook();
		valueOf(testRun, addressbook.id).shouldBeString();
		finish(testRun);
	}
	
	this.getAddressBook = function(testRun) {
		var defAddressbook = tizen.contact.getDefaultAddressBook();
		var defAddressbookId = defAddressbook.id;
		var addressbook = tizen.contact.getAddressBook(defAddressbookId);
		valueOf(testRun, addressbook).shouldBeObject();
		finish(testRun);
	}
	
	this.getAddressBooks = function(testRun) {
		tizen.contact.getAddressBooks(function(addressbooks){
			var addressbooksCount = addressbooks.length;
			valueOf(testRun, addressbooksCount).shouldBeGreaterThan(0);
		}, function(err){
			reportError(testRun, 'The following error occured: ' + err.message);
		});
		finish(testRun);
	}
	
	this.getAddressBookInvalid = function(testRun) {
		
		valueOf(testRun, function(){
			tizen.contact.getAddressBook(-1);
			//reportError(testRun, 'The following error occured: ' + e.message);
		}).shouldThrowException();
		finish(testRun);
	}
	
	this.getContact = function(testRun) {
		var contact = new tizen.Contact({
			name: new tizen.ContactName({
				firstName:'Jeffrey', 
				lastName:'Hyman', 
				nicknames:['joey ramone']
			})
		});
		tizen.contact.getDefaultAddressBook().add(contact);
		valueOf(testRun, function(){tizen.contact.getDefaultAddressBook().get(contact.id)}).shouldNotThrowException();
		finish(testRun);
	}
	
	this.getContactsBatch = function(testRun) {
		var addressbook = tizen.contact.getDefaultAddressBook();
		addressbook.find(function(contacts){
			var contactsCount = contacts.length, contacts = [], i = 0;
			for (; i < 10; i++) {
				contacts.push(new tizen.Contact({firstName:'Jeffrey' + i, lastName:'Hyman' + i}));
			}
			addressbook.addBatch(contacts, function(){
				addressbook.find(function(contacts){
					valueOf(testRun, contacts.length - contactsCount).shouldBe(10);
				}, function(err){
					reportError(testRun, 'The following error occured: ' + err.message);
				})
			}, function(err) {
				reportError(testRun, 'The following error occured: ' + err.message);
			});
		}, function(err){
			reportError(testRun, 'The following error occured: ' + err.message);
		});
		finish(testRun);
	}
	
	this.updateContact = function(testRun) {
		var contact = new tizen.Contact({
			name: new tizen.ContactName({
				firstName:'Jeffrey', 
				lastName:'Hyman', 
				nicknames:['joey ramone']
			})
		}), firstName = 'Jeffrey', addressbook = tizen.contact.getDefaultAddressBook();
		
		addressbook.add(contact);
		contact = addressbook.get(contact.id);
		contact.firstName = "Jeffrey updated";
		addressbook.update(contact);
		contact = addressbook.get(contact.id);
		valueOf(testRun, contact.firstName === firstName).shouldBeFalse();
		finish(testRun);
	}
	
	this.updateBatch = function(testRun) {
		var addressbook = tizen.contact.getDefaultAddressBook();
		addressbook.find(function(contacts){
			var i = 0;
			for (; i < 10; i++) {
				contacts[i].firstName = "John";
			}
			addressbook.updateBatch(contacts, function(){
				addressbook.find(function(contacts){
					var flag = true;
					for (i = 0; i < 10; i++) {
						if (contacts[i].firstName !== "John") {
							flag = false;
							break;
						}
					}
					valueOf(testRun, flag).shouldBeTrue();
				}, function(err){
					reportError(testRun, 'The following error occured: ' + err.message);
				});
			}, function(err) {
				reportError(testRun, 'The following error occured: ' + err.message);
			});
		}, function(err){
			reportError(testRun, 'The following error occured: ' + err.message);
		});
		finish(testRun);
	}
	
	this.removeContact = function(testRun) {
		var addressbook = tizen.contact.getDefaultAddressBook();
		addressbook.find(function(contacts) {
			var contact = contacts[0], id = contact.id;
			addressbook.remove(id);
			valueOf(testRun, function() {
				addressbook.get(id)
			}).shouldThrowException();
		}, function(err) {
			reportError(testRun, 'The following error occured: ' + err.message);
		});
		finish(testRun);
	}
	
	this.removeBatch = function(testRun) {
		var addressbook = tizen.contact.getDefaultAddressBook();
		addressbook.find(function(contacts) {
			addressbook.removeBatch(contacts, function() {
				addressbook.find(function(contacts) {
					valueOf(testRun, contacts.length).shouldBeZero();
				}, function(err) {
					reportError(testRun, 'The following error occured: ' + err.message);
				});
			},  function(err) {
				reportError(testRun, 'The following error occured: ' + err.message);
			})
		},  function(err) {
			reportError(testRun, 'The following error occured: ' + err.message);
		})
		finish(testRun);
	}
	
	this.find = function(testRun) {
		var addressbook = tizen.contact.getDefaultAddressBook(),
			contact = new tizen.Contact({
				name: new tizen.ContactName({
					firstName:'Jeffrey', 
					lastName:'Hyman', 
					nicknames:['joey ramone']
				})
			});
		addressbook.add(contact);
		addressbook.find(function(contacts) {
			valueOf(testRun,  contacts.length).shouldBe(1);
		}, function(err) {
			reportError(testRun, 'The following error occured: ' + err.message);
		});
		finish(testRun);
	}
	
	this.getCategories = function(testRun) {
		var contact = new tizen.Contact({
				name: new tizen.ContactName({
					firstName:'Jeffrey', 
					lastName:'Hyman', 
					nicknames:['joey ramone']
				}),
				categories: ["test"]
			}),
			addressbook = tizen.contact.getDefaultAddressBook();
		addressbook.add(contact);
		contact = addressbook.get(contact.id);
		valueOf(testRun, contact.categories).shouldBeArray();
		valueOf(testRun, contact.categories).shouldContainDeprecated("test");
		finish(testRun);
	}

	this.addAddressBookChangeListener = function(testRun) {
		var counter = 0,
			addressbook = tizen.contact.getDefaultAddressBook(),
			contact = new tizen.Contact({
				name: new tizen.ContactName({
					firstName:'Jeffrey', 
					lastName:'Hyman', 
					nicknames:['joey ramone']
				}),
				categories: ["test"]
			});
		
		watcherId = addressbook.addChangeListener({
			oncontactsadded: function(contacts) {
				counter++;
				valueOf(testRun, counter).shouldBe(1);
			},
			oncontactsupdated: function(contacts) {
				counter++;
				valueOf(testRun, counter).shouldBe(2);
			},
			oncontactsremoved: function(ids) {
				counter++;
				valueOf(testRun, counter).shouldBe(3);
				finish(testRun);
			}
		});
		
		addressbook.add(contact);
		contact = addressbook.get(contact.id);
		contact.firstName = "John";
		addressbook.update(contact);
		addressbook.remove(contact.id);
	}
	
	this.removeAddressbookChangeListener = function(testRun) {
		var addressbook = tizen.contact.getDefaultAddressBook(),
			contact = new tizen.Contact({
				name: new tizen.ContactName({
					firstName:'Jeffrey', 
					lastName:'Hyman', 
					nicknames:['joey ramone']
				}),
				categories: ["test"]
			}), counter = 0;
		
		addressbook.removeChangeListener(watcherId);
		addressbook.add(contact);
		contact = addressbook.get(contact.id);
		contact.firstName = "John";
		addressbook.update(contact);
		addressbook.remove(contact.id);
		valueOf(testRun, counter).shouldBeZero();
		finish(testRun);
	}
	
	this.convertToString = function(testRun) {
		var contact = new tizen.Contact({
				name: new tizen.ContactName({
					firstName:'Jeffrey', 
					lastName:'Hyman', 
					nicknames:['joey ramone']
				}),
				categories: ["test"]
			}), s = "";
		s = contact.convertToString("VCARD_30");
		valueOf(testRun, s.indexOf('Hyman')).shouldBeGreaterThan(0);
		valueOf(testRun, s).shouldBeString();
		finish(testRun);
	}
	
	this.cloneContact = function(testRun) {
		tizen.contact.getDefaultAddressBook().find(function(contacts) {
			var contact = contacts[0], clonedContact = contact.clone();
			valueOf(testRun, clonedContact.id).shouldBeNull();
			finish(testRun);	
		},  function(err) {
			reportError(testRun, 'The following error occured: ' + err.message);
		});
	}
	
	this.contactName = function(testRun) {
		var name = {
				prefix: 'Mr',
				firstName: 'John',
				middleName: 'Glenn',
				lastName: 'Smith',
				nicknames: ['Dee Dee'],
				phoneticFirstName: 'John',
				phoneticLastName: 'Smith'		
			}, 
			contact = new tizen.Contact({
			name: new tizen.ContactName(name)		
		}), status = true, i, j = 0,
		addressbook = tizen.contact.getDefaultAddressBook();
		addressbook.add(contact);
		contact = addressbook.get(contact.id);
		status = ((name.prefix === contact.name.prefix) && (name.firstName === contact.name.firstName) && (name.middleName === contact.name.middleName) && (name.lastName === contact.name.lastName) && (name.nicknames[0] === contact.name.nicknames[0]) && (name.phoneticFirstName === contact.name.phoneticFirstName) && (name.phoneticLastName === contact.name.phoneticLastName));
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactOrganization = function(testRun) {
		var organization = {
			name: 'Intel',
			department: 'department',
			title: 'Director',
			role: 'Programmer',
			logoURI: 'http://upload.wikimedia.org/wikipedia/commons/4/41/Chiswick_Lion.png'
		}, status = true,
		contact = new tizen.Contact({
			organization: new tizen.ContactOrganization(organization)
		});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = ((organization.name === contact.organization.name) && (organization.department === contact.organization.department) && (organization.title === contact.organization.title) && (organization.role === contact.organization.role) && (organization.logoURI === contact.organization.logoURI));
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactWebsite = function(testRun) {
		var website = new tizen.ContactWebSite('http://google.com',  'HOMEPAGE'),
			contact = new tizen.Contact({
				urls: [website]
			}), status = true;
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = ((contact.urls[0].url === 'http://google.com') && (contact.urls[0].type === 'HOMEPAGE'));
		valueOf(testRun,  status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactAnniversary = function(testRun) {
		var anniv = new tizen.ContactAnniversary(new Date(1986, 11, 2), 'Marriage'),
			contact = new tizen.Contact({
				name: new tizen.ContactName({
					fristName: 'Vasa',
					lastName: 'Pupkin'
				}),
				anniversaries: [anniv]
			}), status = true;
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = ((contact.anniversaries[0].date.toString() == new Date(1976, 11, 2).toString()) && (contact.anniversaries[0].label === 'Marriage'));
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactAddress = function(testRun) {
		var address = new tizen.ContactAddress({
				country: 'Ukraine',
				region: 'Lviv',
				city: 'Lviv',
				streetAddress: 'Kotlyarevsky',
				additionalInformation: 'info',
				postalCode: '77600',
				types: ['HOME']
			}), status = true,
			contact = new tizen.Contact({
				addresses: [address]
			});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = ((address.country === contact.addresses[0].country) && (address.region === contact.addresses[0].region) && (address.city === contact.addresses[0].city) && (address.streetAddress === contact.addresses[0].streetAddress) && (address.additionalInformation === contact.addresses[0].additionalInformation) && (address.postalCode === contact.addresses[0].postalCode) && (address.types[0] === contact.addresses[0].types[0]));
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactPhoneNumber = function(testRun) {
		var phoneNumber = new tizen.ContactPhoneNumber('123456789', ['WORK']),
			status = true,
			contact = new tizen.Contact({
				phoneNumbers: [phoneNumber]
			});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = ((contact.phoneNumbers[0].number === '123456789') && (contact.phoneNumbers[0].types[1] === 'WORK'));
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactEmailAddress = function(testRun) {
		var email = new tizen.ContactEmailAddress('user@domain.com', ['WORK','PREF']), status = true,
			contact = new tizen.Contact({
				emails: [email]
			});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = ((contact.emails[0].email === 'user@domain.com') && (contact.emails[0].types[1] === 'WORK'));
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactBirthday = function(testRun) {
		var contact = new tizen.Contact({
			birthday: new Date(1996, 4, 15)
		}), status = true;
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = contact.birthday.toString() === new Date(1996, 4, 15).toString();
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactPhoto = function(testRun) {
		var contact = new tizen.Contact({
			photoURI: 'http://upload.wikimedia.org/wikipedia/commons/4/41/Chiswick_Lion.png'
		});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		console.log(contact.photoURI);
		valueOf(testRun, contact.photoURI).shouldBeString();
		finish(testRun);
	}


	this.contactNote = function(testRun) {
		var contact = new tizen.Contact({
			note: 'test note'
		}), status = true;
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		status = contact.note === 'test note';
		valueOf(testRun, status).shouldBeTrue();
		finish(testRun);
	}
	
	this.isFavorite = function(testRun) {
		var contact = new tizen.Contact({
			isFavorite: true,
			name: new tizen.ContactName({
				firstName: 'Vasa'
			})
		});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		console.log(contact.isFavorite);
		valueOf(testRun,  contact.isFavorite).shouldBeTrue();
		finish(testRun);
	}
	
	this.contactRingtoneURI = function(testRun) {
		var contact = new tizen.Contact({
			name: new tizen.ContactName({
				fristName: 'Vasa'
			}),
			ringtoneURI: 'file:///opt/media/Sounds/dz_dzo_-_yalta_.mp3'
		});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		console.log(contact.ringtoneURI);
		valueOf(testRun, contact.ringtoneURI).shouldBeString();
		finish(testRun);
	}
	
	this.contactLastUpdated = function(testRun) {
		var contact = new tizen.Contact({
				name: new tizen.ContactName({
					firstName: 'Vasa'
				})
			});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		valueOf(testRun, contact.lastUpdated).shouldBeObject();
		valueOf(testRun, contact.lastUpdated.toString()).shouldBeString();
		finish(testRun);
	}
	
	this.contactAddressBookId = function(testRun) {
		var contact = new tizen.Contact({
			name: new tizen.ContactName({
				firstName: 'Vasa'
			})
		});
		_addressbook.add(contact);
		contact = _addressbook.get(contact.id);
		valueOf(testRun, contact.addressBookId).shouldBeString();
		finish(testRun);
	}
}