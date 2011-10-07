module main;

import lib.fcgi;
import lib.util;

import tango.io.Stdout;
import tango.io.device.Array;
import tango.io.device.File;
import tango.io.FilePath;

import tango.util.log.Log;
import tango.util.log.AppendFile;
import tango.util.log.LayoutDate;

import croc.api;
import croc.ex;
import croc.ex_bind;

import enabled_modules;

import tango.core.tools.TraceExceptions;

void main(char[][] args)
{	try
	{
		//set up logging
		auto fp = FilePath(getExePath());
		fp.pop();
		fp.append("error.log");
		
		if(!fp.exists())
		{
			auto f = new File(fp.toString, File.ReadWriteCreate);
			f.close();
		}
		
		//log to exe-path/error.log
		Log.root.add(new AppendFile(fp.toString, new LayoutDate()));
		Log.root.level = Level.Trace;
		
		auto log = Log.lookup("main");
		
		log.info("starting croc-fcgi");

		FCGI_Request r;
		
		CrocVM vm;
		
		auto t = openVM(&vm);
		loadStdlibs(t, CrocStdlib.Safe);
	
		while(FCGX.accept(r, true) >= 0)
		{
			pushRequest(t, r);
			initModules(t);
			
			runFile(t, r.env["SCRIPT_FILENAME"]);
			r.finish();
			
			closeVM(&vm);
			t = openVM(&vm);
			loadStdlibs(t, CrocStdlib.Safe);
		}
	}
	catch(Exception e)
	{
		auto f = new File("C:\\Users\\Andre\\Documents\\croc-fcgi\\crash.log", File.ReadWriteCreate);
		void sink(char[] msg)
		{
			   f.write(msg);
		}
		sink(e.toString);
		if(e.info)
		{
				sink("\r\n");
				e.info.writeOut(&sink);
		}
		f.close();
	}
	
	//log.info("closing log");
}
