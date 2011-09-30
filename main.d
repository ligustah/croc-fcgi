module main;

import lib.fcgi;
import lib.util;

import tango.io.Stdout;

import croc.api;
import croc.ex;
import croc.ex_bind;

import enabled_modules;

import tango.core.tools.TraceExceptions;

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
			runFile(t, r.env["SCRIPT_FILENAME"]);
		}
		catch(Exception e)
		{
			void sink(char[] msg)
			{
				Stdout(msg);
			}
			sink(e.toString);
			if(e.info)
			{
				sink("\r\n");
				e.info.writeOut(&sink);
			}
		}
		
		closeVM(&vm);
		t = openVM(&vm);
		loadStdlibs(t, CrocStdlib.Safe);
	}
}