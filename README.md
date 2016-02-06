# LDSAnnotations

[![Pod Version](https://img.shields.io/cocoapods/v/LDSAnnotations.svg)](LDSAnnotations.podspec)
[![Pod License](https://img.shields.io/cocoapods/l/LDSAnnotations.svg)](LICENSE)
[![Pod Platform](https://img.shields.io/cocoapods/p/LDSAnnotations.svg)](LDSAnnotations.podspec)
[![Build Status](https://img.shields.io/travis/CrossWaterBridge/LDSAnnotations.svg?branch=master)](https://travis-ci.org/CrossWaterBridge/LDSAnnotations)

Swift client library for LDS annotation sync.

### Installation

Install with Cocoapods by adding the following to your Podfile:

```
use_frameworks!

pod 'LDSAnnotations'
```

Then run:

```
pod install
```

### Tests

The tests can be run from the `LDSAnnotationsDemo` scheme. The tests require a client
username and password, as well as a test LDS Account username and password. You will
need to supply these credentials through the “Arguments Passed On Launch” in the scheme.

The easiest way to do this is to duplicate the `LDSAnnotationsDemo` scheme (naming it 
something like `LDSAnnotationsDemo with Secrets`) and replace the environment variables
with the actual values. Be sure to not check the Shared box for this scheme so that it
isn’t accidentally committed.

### Travis CI

The test credentials are encrypted in the `.travis.yml` for use when building on
Travis CI. To update the credentials, use the following command (substituting the
appropriate values):

```bash
travis encrypt --add --override \
    "CLIENT_USERNAME=<value>" \
    "CLIENT_PASSWORD=<value>" \
    "LDSACCOUNT_USERNAME=<value>" \
    "LDSACCOUNT_PASSWORD=<value>"
```

### License

LDSAnnotations is released under the MIT license. See LICENSE for details.