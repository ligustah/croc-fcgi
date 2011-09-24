module main;

import lib.fcgi;
import lib.util;

import tango.io.Stdout;

import croc.api;
import croc.ex;
import croc.ex_bind;

import enabled_modules;

void main()
{
	FCGI_Request r;
	
	CrocVM vm;
	
	auto t = openVM(&vm);
	loadStdlibs(t, CrocStdlib.Safe);
	
	while(FCGX.accept(r, true) >= 0)
	{
		Stdout("Content-Type: text/plain").newline.newline;
		pushRequest(t, r);
		initModules(t);
		
		try
		{
			runFile(t, r.params["SCRIPT_FILENAME"]);
		}
		catch(Exception e)
		{
			Stdout(e).newline;
		}
		
		closeVM(&vm);
		t = openVM(&vm);
		loadStdlibs(t, CrocStdlib.Safe);
	}
}