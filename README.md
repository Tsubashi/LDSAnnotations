# LDSAnnotations

[![Pod Version](https://img.shields.io/cocoapods/v/LDSAnnotations.svg)](LDSAnnotations.podspec)
[![Pod License](https://img.shields.io/cocoapods/l/LDSAnnotations.svg)](LICENSE)
[![Pod Platform](https://img.shields.io/cocoapods/p/LDSAnnotations.svg)](LDSAnnotations.podspec)
[![Build Status](https://img.shields.io/travis/CrossWaterBridge/LDSAnnotations.svg?branch=master)](https://travis-ci.org/CrossWaterBridge/LDSAnnotations)

Swift client library for LDS annotation sync.

### Installation

Install with CocoaPods by adding the following to your Podfile:

```ruby
use_frameworks!

pod 'LDSAnnotations'
```

Then run:

```bash
pod install
```

### Demo and Tests

The demo app and tests can be run from the `LDSAnnotationsDemo` scheme. The demo app
requires a client username and password (to authorize use of the API for the app).
To run the tests you will also need a test LDS Account username and password (don’t use
an account that has annotations you care about). You will need to supply these credentials
through the “Arguments Passed On Launch” in the scheme.

The easiest way to do this is to duplicate the `LDSAnnotationsDemo` scheme (naming it 
something like `LDSAnnotationsDemo with Secrets`) and replace the environment variables
with the actual values. Be sure to not check the Shared box for this scheme so that it
isn’t accidentally committed.

### Travis CI

The test credentials are encrypted in the `.travis.yml` for use when building on
Travis CI. To update the credentials:

1. Install the [Travis client](https://github.com/travis-ci/travis.rb):

	```bash
	sudo gem install travis
	```

2. Run the following command (substituting the appropriate values; be sure to escape any `bash` symbols):

	```bash
	travis encrypt --add --override \
		"CLIENT_USERNAME=<value>" \
		"CLIENT_PASSWORD=<value>" \
		"TEST_ACCOUNT_USERNAME=<value>" \
		"TEST_ACCOUNT_PASSWORD=<value>"
	```

### License

LDSAnnotations is released under the MIT license. See LICENSE for details.