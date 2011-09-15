module http.http;

import croc.api;
import lib.fcgi;

import tango.io.Stdout;

void init_http(CrocThread* t, FCGI_Request r)
{
	Stdout("http module initialised!").newline;
}