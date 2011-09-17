This is a general purpose fcgi server to host Croc applications.

#Depends on
* libfcgi (32 bit), which can be built on 64 bit machines like this:

        CC="gcc -m32" CXX="g++ -m32" ./configure
        make
        make install


* DMD 1 / Tango