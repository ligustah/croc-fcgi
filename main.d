module main;

import lib.fcgi;
import lib.util;

import tango.io.Stdout;
import tango.io.device.Array;

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
		try
		{
			pushRequest(t, r);
			initModules(t);
		
			runFile(t, r.env["SCRIPT_FILENAME"]);
			r.finish();
		}
		catch(Exception e)
		{
			auto a = new Array(128, 128);
			void sink(char[] msg)
			{
				a.write(msg);
			}
			sink(e.toString);
			if(e.info)
			{
				sink("\r\n");
				e.info.writeOut(&sink);
			}
			Stdout(cast(char[])a.slice);
		}
		
		closeVM(&vm);
		t = openVM(&vm);
		loadStdlibs(t, CrocStdlib.Safe);
	}
}