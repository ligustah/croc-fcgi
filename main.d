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

private Logger log;

static this()
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
	
	log = Log.lookup("main");
}

void main(char[][] args)
{	try
	{
		log.info("starting croc-fcgi");

		FCGI_Request r;
		
		CrocVM vm;
		CrocThread *t = openVM(&vm);	//warmup
	
		while(FCGX.accept(r, true) >= 0)
		{
			try
			{
				log.trace("1");
				pushRequest(t, r);
				log.trace("2");
				initModules(t);
				log.trace("3");
				
				log.trace("4");
				runFile(t, r.env["SCRIPT_FILENAME"]);
				log.trace("5");
				r.finish();		
			} catch(Exception e)
			{
				auto f = new File(getExeDir().append("exception.log").toString, File.ReadWriteCreate);
				void snk(char[] msg)
				{
					   f.write(msg);
				}
				snk(e.toString);
				if(e.info)
				{
						snk("\r\n");
						e.info.writeOut(&snk);
				}
			} finally
			{
				closeVM(&vm);
				t = openVM(&vm);
			}
		}
	}
	catch(Exception e)
	{
		auto f = new File(getExeDir().append("crash.log").toString, File.ReadWriteCreate);
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
