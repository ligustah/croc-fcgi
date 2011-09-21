module http;

import croc.api;
import croc.ex_bind;
import lib.fcgi;
import lib.util;

import tango.io.Stdout;

void http_init(CrocThread* ct)
{	
	makeModule(ct, "http", &HttpModule.init);
}

struct HttpModule
{
static:
	uword init(CrocThread* t)
	{
		superPush(t, getRequest(t).params);
		newGlobal(t, "params");
		
		return 0;
	}
}