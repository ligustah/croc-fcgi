module http;

import croc.api;
import lib.fcgi;

import tango.io.Stdout;

void http_init(CrocThread* t, FCGI_Request r)
{
	Stdout("http module initialised!").newline;
}