module http;

import croc.api;
import croc.ex_bind;
import lib.fcgi;

import tango.io.Stdout;

static FCGI_Request request;

void http_init(CrocThread* ct, FCGI_Request r)
{
	HttpGlobals.r = r;
	
	makeModule(ct, "http", &HttpGlobals.init);
}

struct HttpGlobals
{
	static FCGI_Request r;
	
	static uword init(CrocThread* t)
	{
		superPush(t, r.params);
		newGlobal(t, "params");
		
		return 0;
	}
}