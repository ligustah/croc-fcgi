module main;

import lib.fcgi;

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
		initModules(t, r);
		
		superPush(t, r.params);
		newGlobal(t, "params");
		
		try
		{
			runFile(t, r.params["SCRIPT_FILENAME"]);
		}
		catch(CrocException e)
		{
			Stdout(e).newline;
		}
		
		closeVM(&vm);
		t = openVM(&vm);
		loadStdlibs(t, CrocStdlib.Safe);
	}
}