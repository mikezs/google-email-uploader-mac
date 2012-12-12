#Google Email Uploader for Mac

This is a straight fork of the [Google Code Project](http://code.google.com/p/google-email-uploader-mac/) that uploads email from your Mail.app to GMail.

## Why?

There's a bug that I encountered when uploading my 14,000 emails to my google apps account, which means that the mailbox names get ignored and are replaced with the cached sub-folders named 1, 2, 3, 4, 5, 6, 7, 8, 9 and Data.

I've fixed this by setting each message's parent to the last folder with .mbox in the path.

## Compiling/Installing

This is the first OS X project I've worked on (I'm an iOS developer) so I assume it'll just work for you. Just open the project in Xcode and run!

## Requirements:

* OS X 10.7, **NOT 10.8**

There's missing API's in 10.8 that stop the app compiling, so I don't support it.