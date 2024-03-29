#!/usr/bin/env rdmd --shebang
/**
 * License: Boost 1.0
 *
 * Copyright (c) 2009-2010 Eric Poggel
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Description:
 *
 * This is a D programming language build script (and library) that can be used
 * to compile D (version 1) source code.  Unlike Bud, DSSS/Rebuild, Jake, and
 * similar tools, CDC is contained within a single file that can easily be
 * distributed with projects.  This simplifies the build process since no other
 * tools are required.  The main() function can be utilized to turn
 * CDC into a custom build script for your project.
 *
 * CDC's only requirement is a D compiler.  It is/will be supported on any 
 * operating system supported by the language.  It works with dmd, ldc (soon), 
 * and gdc, phobos or tango.
 *
 * CDC can be used just like dmd, except for the following improvements.
 * <ul>
 *   <li>CDC can accept paths as as well as individual source files for compilation.
 *    Each path is recursively searched for source, library, object, and ddoc files.</li>
 *   <li>CDC automatically creates a modules.ddoc file for use with CandyDoc and
 *    similar documentation utilities.</li>
 *   <li>CDC defaults to use the compiler that was used to build itself.  Compiler
 *    flags are passed straight through to that compiler.</li>
 *   <li>The -op flag is always used, to prevent name conflicts in object and doc files.</li>
 *   <li>Documentation files are all placed in the same folder with their full package
 *    names.  This makes relative links between documents easier.</li>
 * </ul>

 * These DMD/LDC options are automatically translated to the correct GDC
 * options, or handled manually:
 * <dl>
 * <dt>-c</dt>         <dd>do not link</dd>
 * <dt>-D</dt>         <dd>generate documentation</dd>
 * <dt>-Dddocdir</dt>  <dd>write fully-qualified documentation files to docdir directory</dd>
 * <dt>-Dfdocfile</dt> <dd>write fully-qualified documentation files to docfile file</dd>
 * <dt>-lib</dt>       <dd>Generate library rather than object files</dd>
 * <dt>-run</dt>       <dd>run resulting program, passing args</dd>
 * <dt>-Ipath</dt>     <dd>where to look for imports</dd>
 * <dt>-o-</dt>        <dd>do not write object file.</dd>
 * <dt>-offilename</dt><dd>name output file to filename</dd>
 * <dt>-odobjdir</dt>  <dd>write object & library files to directory objdir</dd>
 * </dl>
 *
 * In addition, these optional flags have been added.
 * <dl>
 * <dt>-dmd</dt>       <dd>Use dmd to compile</dd>
 * <dt>-gdc</dt>       <dd>Use gdc to compile</dd>
 * <dt>-ldc</dt>       <dd>Use ldc to compile</dd>
 * <dt>-verbose</dt>   <dd>Print all commands as they're executed.</dd>
 * <dt>-root</dt>      <dd>Set the root directory of all source files.
 *                 This is useful if CDC is run from a path outside the source folder.</dd>
 * </dl>
 *
 * Bugs:
 * <ul>
 * <li>Doesn't yet work with LDC.  See dsource.org/projects/ldc/ticket/323</li>
 * <li>Dmd writes out object files as foo/bar.o, while gdc writes foo.bar.o</li>
 * <li>Dmd fails to write object files when -od is an absolute path.</li>
 * </ul>
 *
 * Test_Matrix:
 * <ul>
 * <li>pass - DMD/phobos/Win32</li>
 * <li>pass - DMD/tango/Win32</li>
 * <li>pass - DMD/tango/Linux32</li>
 * <li>pass - GDC/phobos/Win32</li>
 * <li>pass - GDC/phobos/Linux32</li>
 * <li>fail - LDC/tango/Linux32</li>
 * <li>pass - GDC/phobos/OSX</li>
 * <li>? - DMD/OSX</li>
 * <li>? - BSD</li>
 * <li>? - DMD2</li>
 * </ul>
 *
 * TODO:
 * <ul>
 * <li>Add support for a -script argument to accept another .d file that calls cdc's functions.</li>
 * <li>Print help or at least info on run.</li>
 * <li>-Df option</li>
 * <li>GDC - Remove dependancy on "ar" on windows? </li>
 * <li>LDC - Scanning a folder for files is broken. </li>
 * <li>Test with D2</li>
 * <li>Unittests</li>
 * <li>More testing on paths with spaces. </li>
 * </ul>
 *
 * API:
 * Use any of these functions in your own build script.
 */

module build;

import lib.ini;

import tango.io.stream.Format;
import Integer = tango.text.convert.Integer;

/**
 * Use to implement your own custom build script, or pass args on to defaultBuild() 
 * to use this file as a generic build script like bud or rebuild. */
int main(string[] args)
{
	char[][] defaultArgs = ["-Icroc-src", "-debug", "-g"];
	char[] croc_lib = "lib/croc" ~ lib_ext;
	char[] croc_bin = "lib/crocc" ~ bin_ext;
	
	if (!FS.exists(croc_lib))
	{
		Stdout("[+] making croc lib").newline;
		CDC.compile(["croc-src/croc"], ["-lib", "-debug", "-g", "-of" ~ croc_lib]);
	}
	
	if(!FS.exists(croc_bin))
	{
		Stdout("[+] making crocc").newline;
		CDC.compile(["croc-src/crocc.d", croc_lib], ["-of" ~ croc_bin, "-Icroc-src", "-profile"]);
	}
	
	auto modules = compileModules();
	defaultArgs ~= includeModules(modules, "modules/");
	
	defaultArgs ~= linkModules(modules, "modules/");
	
	CDC.compile(["lib", "main.d", "enabled_modules.d"], defaultArgs ~ ["-ofcroc-fcgi"], null, null, true);
	return 0;
}

char[][] linkModules(char[][] modules, char[] base)
{
	char[][] ret;
	
	foreach(mod; modules)
	{
		ret ~= base ~ mod ~ lib_ext;
	}
	
	return ret;
}

char[][] includeModules(char[][] modules, char[] base)
{
	auto outF = new File("enabled_modules.d_", File.ReadWriteCreate);
	auto f = new FormatOutput!(char)(outF);
	char[][] imports;
	
	f("module enabled_modules;").newline.newline;
	
	f("import croc.api;").newline;
	f("import lib.util;").newline;
	f("import lib.fcgi;").newline.newline;
	
	foreach(mod; modules)
	{
		f.formatln("import {0};", mod);
		imports ~= "-I" ~ base ~ mod;
	}
	
	f(
`uword loadScriptModule(CrocThread* t)
{
	uword numReturns = 0;
	
	checkStringParam(t, 1);
	
	auto tab = getRegistryVar(t, "fcgi.scriptModules");
	dup(t, 1);
	
	field(t, tab);
	
	if(isString(t, -1))
	{
		char[] name = getString(t, 1);
		importModuleFromString(t, name, getString(t, -1), name ~ ".croc");
		
		numReturns = 1;
	}
	
	return numReturns;
}`);
	
	f.newline;
	f("void initModules(CrocThread* t){").newline;
	f("\tgetRegistry(t);").newline;
	f("\tpushString(t, \"croc.bind.initialized\");").newline;
	f("\tif(!opin(t, -1, -2)){").newline;
	f("\t\tnewTable(t);       fielda(t, -3, \"croc.bind.WrappedClasses\");").newline;
	f("\t\tnewTable(t);       fielda(t, -3, \"croc.bind.WrappedInstances\");").newline;
	f("\t\tpushBool(t, true); fielda(t, -3);").newline;
	f("\t\tpop(t);").newline;
	f("\t}").newline;
	f("\telse").newline;
	f("\t\tpop(t, 2);").newline;
	f.newline;
	
	f(
`	auto dest = lookupCT!("modules.loaders")(t);
	newFunction(t, 1, &loadScriptModule, "loadBundled");
	cateq(t, dest, 1);
	pop(t);
	newTable(t);
	setRegistryVar(t, "fcgi.scriptModules");
	
	auto console = importModule(t, "console");
	auto stream = importModule(t, "stream");

		field(t, stream, "InStream");
		pushNull(t);
		pushNativeObj(t, cast(Object)getRequest(t).input);
		pushBool(t, false);
		rawCall(t, -4, 1);
	fielda(t, console, "stdin");

		field(t, stream, "OutStream");
		pushNull(t);
		pushNativeObj(t, cast(Object)getRequest(t).output);
		pushBool(t, false);
		rawCall(t, -4, 1);
	fielda(t, console, "stdout");

		field(t, stream, "OutStream");
		pushNull(t);
		pushNativeObj(t, cast(Object)getRequest(t).error);
		pushBool(t, false);
		rawCall(t, -4, 1);
	fielda(t, console, "stderr");

	pop(t);

	`).newline;
	
	foreach(mod; modules)
	{
		f.formatln("\t{}_init(t);", mod);
	}
	f("}");
	
	f.flush;
	f.close;
	
	return imports;
}

char[] scriptImport(FilePath mod, char[][] crocos)
{
	char[] path = mod.dup.append(mod.name).suffix(".d_").toString;
	
	if(!crocos.length)
		return path;
	
	Stdout.formatln("[*] writing script import file to {}", path);
	auto outF = new File(path, File.ReadWriteCreate);
	auto f = new FormatOutput!(char)(outF);
	
	f.formatln("module {};", mod.name);
	
	f("import croc.api;").newline;
	f("import croc.api_debug;").newline;
	f("import croc.serialization;").newline;
	f("import tango.io.device.Array;").newline;
	f("import tango.io.Stdout;").newline;
	
	
	int i = 0;
	ubyte[1] buf;
	
	foreach(k,v; crocos)
	{
		auto inF = new File(v, File.ReadExisting);
		f.format("private const ubyte[{}] module_data = [", inF.length, i++);
		
		while(inF.read(buf) != File.Eof) {
			f.format("{:x#},", buf[0]);
		}
		
		f.formatln("];");
		inF.close;
	}
	
	//f.formatln("static void[] module_data_{} = import(\"{}\");", k, v);
	
	f.formatln("void {}_init(CrocThread* t)", mod.name);
	f("{").newline;
	f.formatln("\tmakeModule(t, \"{0}\", &{0}_loader);", mod.name).newline;
	f("}").newline;
	
	f.formatln("uword {}_loader(CrocThread* t)", mod.name);
	f("{ printStack(t);").newline;
	f("\tauto a = new Array(module_data);").newline;
	f("\tchar[] loadName = void;").newline;
	f("\tdeserializeModule(t, loadName, a); pop(t); printStack(t);").newline;
	f("\treturn 1;").newline;
	f("}").newline;
	
//	f("{").newline;
//	f("{").newline;
//	f("{").newline;
//	f("{").newline;
	
	f.flush;
	f.close;
	
	return path;
}

char[][] compileModules()
{
	FilePath[] modules = FilePath("modules").toList((FilePath path, bool isFolder)
			{
				return isFolder;
			});
	
	char[][] moduleNames;
	
	foreach(mod; modules)
	{
		auto f = mod.dup.append("build.ini");
		
		if(!f.exists) // no ini? no module!
			continue;
			
		auto conf = new Ini(f.toString());
		
		char[] type = conf.section["type"];
		conf.section.set("name", mod.name);
		
		Stdout.formatln("[*] module: {} type: {}", mod.name, type);
		moduleNames ~= mod.name();
		
		//compile it, if needed
		auto libFile = FilePath("modules/" ~ mod.name ~ lib_ext);
		
		if(libFile.exists())	//check if we have to recompile
		{
			if(findNewest(mod) > libFile.modified)
			{
				Stdout.formatln("[*] module {} modified, recompiling", mod.name);
			}
			else
			{
				Stdout.formatln("[*] skipping module {}, already up to date", mod.name);
				continue;
			}
		}
		
		char[][] arguments;
		
		for(int arg = 1; conf.section.has("arg" ~ Integer.toString(arg)); arg++)
		{
			arguments ~= conf.section["arg" ~ Integer.toString(arg)];
		}
		
		switch(type)
		{
			case "native":
				compileNative(mod, libFile, arguments);
				break;
			case "script":
				compileScript(mod, libFile, arguments);
				break;
			default:
				Stdout.formatln("[-] unknown type '{}' for module '{}'", type, mod.name);
		}
	}
	
	return moduleNames;
}

void compileNative(FilePath mod, FilePath libFile, char[][] arguments)
{
	//one command to rule them all!
	CDC.compile(["."], ["-debug", "-g", "-I../../croc-src", "-I../../", "-lib", "-of../../" ~ libFile.toString] ~ arguments, null, mod.toString, true);
}

void compileScript(FilePath mod, FilePath libFile, char[][] arguments)
{
	foreach(file; FS.scan(mod.toString, [".croc"]))	
		System.execute("lib" ~ FS.sep ~ "crocc" ~ bin_ext, [file]);
	
	char[][] crocos = FS.scan(mod.toString, [".croco"]);
	char[] path = scriptImport(mod, crocos);
	if(path.length)
	{
		compileNative(mod, libFile, arguments);
		
		foreach(croco; crocos)
			FS.remove(croco);
	}
}

/**
	recursively find the newest file under 'base'
*/
Time findNewest(FilePath base, Time current = Time.min)
{
	foreach(file; base.toList)
	{
		if(file.isFile)
		{
			if(file.modified > current)
				current = file.modified;
		}
		else
		{
			current = findNewest(file, current);
		}
	}
	return current;
}

/*
 * ----------------------------------------------------------------------------
 * CDC Code, modify with caution
 * ----------------------------------------------------------------------------
 */

// Imports
import tango.core.Array : find;
import tango.core.Exception;
import tango.core.Thread;
import tango.io.device.File;
import tango.io.FilePath;
import tango.io.FileScan;
import tango.io.FileSystem;
import tango.io.Stdout;
import tango.sys.Environment;
import tango.text.convert.Format;
import tango.text.Regex;
import tango.text.Util;
import tango.text.Ascii;
import tango.time.Clock;
import tango.util.Convert;
extern (C) int system(char *);  // Tango's process hangs sometimes
//import tango.core.tools.TraceExceptions; // enable to get stack trace in buildyage.d on internal failure


/// This is always set to the name of the default compiler, which is the compiler used to build cdc.
version (DigitalMars)
	string compiler = "dmd";
version (GNU)
	string compiler = "gdc"; /// ditto
version (LDC)
	string compiler = "ldmd";  /// ditto

version (Windows)
{	const string[] obj_ext = [".obj", ".o"]; /// An array of valid object file extensions for the current.
	const string lib_ext = ".lib"; /// Library extension for the current platform.
	const string bin_ext = ".exe"; /// executable file extension for the current platform.
}
else
{	const string[] obj_ext = [".o"]; /// An array of valid object file extensions for the current.
	const string lib_ext = ".a"; /// Library extension for the current platform.
	const string bin_ext = ""; /// Executable file extension for the current platform.
}

/**
 * Program entry point.  Parse args and run the compiler.*/
int defaultBuild(string[] args)
{	args = args[1..$];// remove self-name from args

	string root;
	string[] options;
	string[] paths;
	string[] run_args;
	bool verbose;

	// Populate options, paths, and run_args from args
	bool run;
	foreach (arg; args)
	{	switch (arg)
		{	case "-verbose": verbose = true; break;
			case "-dmd": compiler = "dmd"; break;
			case "-gdc": compiler = "gdc"; break;
			case "-ldc": compiler = "ldc"; break;
			case "-run": run = true; options~="-run";  break;
			default:
				if (String.starts(arg, "-root"))
				{	root = arg[5..$];
					continue;
				}

				if (arg[0] == '-' && (!run || !paths.length))
					options ~= arg;
				else if (!run || FS.exists(arg))
					paths ~= arg;
				else if (run && paths.length)
					run_args ~= arg;
	}	}

	// Compile
	CDC.compile(paths, options, run_args, root, verbose);

	return 0; // success
}

/**
 * A library for compiling d code.
 * Example:
 * --------
 * // Compile all source files in src/core along with src/main.d, link with all library files in the libs folder,
 * // generate documentation in the docs folder, and then run the resulting executable.
 * CDC.compile(["src/core", "src/main.d", "libs"], ["-D", "-Dddocs", "-run"]);
 * --------
 */
struct CDC
{
	/**
	 * Compile d code using same compiler that compiled CDC.
	 * Params:
	 *     paths = Array of source and library files and folders.  Folders are recursively searched.
	 *     options = Compiler options.
	 *     run_args = If -run is specified, pass these arguments to the generated executable.
	 *     root = Use this folder as the root of all paths, instead of the current folder.  This can be relative or absolute.
	 *     verbose = Print each command before it's executed.
	 * Returns:
	 *     Array of commands that were executed.
	 * TODO: Add a dry run option to just return an array of commands to execute. */
	static string[] compile(string[] paths, string[] options=null, string[] run_args=null, string root=null, bool verbose=false)
	{	Log.operations = null;
		Log.verbose = verbose;

		// Change to root directory and back again when done.
		string cwd = FS.getDir();
		if (root.length)
		{	if (!FS.exists(root))
				throw new Exception(`Directory specified for -root "` ~ root ~ `" doesn't exist.`);
			FS.chDir(root);
		}
		scope(exit)
			if (root.length)
				FS.chDir(cwd);

		// Convert src and lib paths to files
		string[] sources;
		string[] libs;
		string[] ddocs;
		foreach (src; paths)
			if (src.length)
			{	if (!FS.exists(src))
					throw new Exception(`Source file/folder "` ~ src ~ `" does not exist.`);
				if (FS.isDir(src)) // a directory of source or lib files
				{	sources ~= FS.scan(src, [".d"]);
					ddocs ~= FS.scan(src, [".ddoc"]);
					libs ~= FS.scan(src, [lib_ext]);
				} else if (FS.isFile(src)) // a single file
				{
					scope ext = src[String.rfind(src, ".")..$];
					if (".d" == ext)
						sources ~= src;
					else if (lib_ext == ext)
						libs ~= src;
				}
			}

		// Add dl.a for dynamic linking on linux
		version (linux)
			libs ~= ["-L-ldl"];

		// Combine all options, sources, ddocs, and libs
		CompileOptions co = CompileOptions(options, sources);
		options = co.getOptions(compiler);
		if (compiler=="gdc")
			foreach (ref d; ddocs)
				d = "-fdoc-inc="~d;
		else foreach (ref l; libs)
			version (GNU) // or should this only be version(!Windows)
				l = `-L`~l; // TODO: Check in dmd and gdc

		// Create modules.ddoc and add it to array of ddoc's
		if (co.D)
		{	string modules = "MODULES = \r\n";
			sources.sort;
			foreach(string src; sources)
			{	src = String.split(src, "\\.")[0]; // get filename
				src = String.replace(String.replace(src, "/", "."), "\\", ".");
				modules ~= "\t$(MODULE "~src~")\r\n";
			}
			FS.write("modules.ddoc", modules);
			ddocs ~= "modules.ddoc";
			scope(failure) FS.remove("modules.ddoc");
		}
		
		string[] arguments = options ~ sources ~ ddocs ~ libs;

		// Compile
		if (compiler=="gdc")
		{
			// Add support for building libraries to gdc.
			if (co.lib || co.D || co.c) // GDC must build incrementally if creating documentation or a lib.
			{
				// Remove options that we don't want to pass to gcd when building files incrementally.
				string[] incremental_options;
				foreach (option; options)
					if (option!="-lib" && !String.starts(option, "-o"))
						incremental_options ~= option;

				// Compile files individually, outputting full path names
				string[] obj_files;
				foreach(source; sources)
				{	string obj = String.replace(source, "/", ".")[0..$-2]~".o";
					string ddoc = obj[0..$-2];
					if (co.od)
						obj = co.od ~ FS.sep ~ obj;
					obj_files ~= obj;
					string[] exec = incremental_options ~ ["-o"~obj, "-c"] ~ [source];
					if (co.D) // ensure doc files are always fully qualified.
						exec ~= ddocs ~ ["-fdoc-file="~ddoc~".html"];
					System.execute(compiler, exec); // throws ProcessException on compile failure
				}

				// use ar to join the .o files into a lib and cleanup obj files (TODO: how to join on GDC windows?)
				if (co.lib)
				{	FS.remove(co.of); // since ar refuses to overwrite it.
					System.execute("ar", "cq "~ co.of ~ obj_files);
				}

				// Remove obj files if -c or -od not were supplied.
				if (!co.od && !co.c)
					foreach (o; obj_files)
						FS.remove(o);
			}

			if (!co.lib && !co.c)
			{
				// Remove documentation arguments since they were handled above
				string[] nondoc_args;
				foreach (arg; arguments)
					if (!String.starts(arg, "-fdoc") && !String.starts(arg, "-od"))
						nondoc_args ~= arg;

				executeCompiler(compiler, nondoc_args);
			}
		}
		else // (compiler=="dmd" || compiler=="ldc")
		{	
			executeCompiler(compiler, arguments);		
			// Move all html files in doc_path to the doc output folder and rename with the "package.module" naming convention.
			if (co.D)
			{	foreach (string src; sources)
				{	
					if (src[$-2..$] != ".d")
						continue;

					string html = src[0..$-2] ~ ".html";
					string dest = String.replace(String.replace(html, "/", "."), "\\", ".");
					if (co.Dd.length)
					{	
						dest = co.Dd ~ FS.sep ~ dest;
						html = co.Dd ~ FS.sep ~ html;
					}
					if (html != dest) // TODO: Delete remaining folders where source files were placed.
					{	FS.copy(html, dest);
						FS.remove(html);
			}	}	}
		}

		// Remove extra files
		string basename = co.of[String.rfind(co.of, "/")+1..$];
		FS.remove(String.changeExt(basename, ".map"));
		if (co.D)
			FS.remove("modules.ddoc");
		if (co.of && !(co.c || co.od))
			foreach (ext; obj_ext)
				FS.remove(String.changeExt(co.of, ext)); // delete object files with same name as output file that dmd sometimes leaves.

		// If -run is set.
		if (co.run)
		{	System.execute("./" ~ co.of, run_args);
			version(Windows) // Hack: give dmd windows time to release the lock.
				if (compiler=="dmd")
					System.sleep(.1);
			FS.remove(co.of); // just like dmd
		}

		return Log.operations;
	}

	// A wrapper around execute to write compile options to a file, to get around max arg lenghts on Windows.
	private static void executeCompiler(string compiler, string[] arguments)
	{	try {
			version (Windows)
			{	FS.write("compile", String.join(arguments, " "));
				scope(exit)
					FS.remove("compile");
				System.execute(compiler~" ", ["@compile"]);
			} else
				System.execute(compiler, arguments);
		} catch (ProcessException e)
		{	throw new Exception("Compiler failed.");
		}
	}

	/*
	 * Store compilation options that must be handled differently between compilers
	 * This also implicitly enables -of and -op for easier handling. */
	private struct CompileOptions
	{
		bool c;				// do not link
		bool D;				// generate documentation
		string Dd;			// write documentation file to this directory
		string Df;			// write documentation file to this filename
		bool lib;			// generate library rather than object files
		bool o;				// do not write object file
		string od;			// write object & library files to this directory
		string of;			// name of output file.
		bool run;
		string[] run_args;	// run immediately afterward with these arguments.

		private string[] options; // stores modified options.

		/*
		 * Constructor */
		static CompileOptions opCall(string[] options, string[] sources)
		{	CompileOptions result;
			foreach (i, option; options)
			{
				if (option == "-c")
					result.c = true;
				else if (option == "-D" || option == "-fdoc")
					result.D = true;
				else if (String.starts(option, "-Dd"))
					result.Dd = option[3..$];
				else if (String.starts(option, "-fdoc-dir="))
					result.Df = option[10..$];
				else if (String.starts(option, "-Df"))
					result.Df = option[3..$];
				else if (String.starts(option, "-fdoc-file="))
					result.Df = option[11..$];
				else if (option == "-lib")
					result.lib = true;
				else if (option == "-o-" || option=="-fsyntax-only")
					result.o = true;
				else if (String.starts(option, "-of"))
					result.of = option[3..$];
				else if (String.starts(option, "-od"))
					result.od = option[3..$];
				else if (String.starts(option, "-o") && option != "-op")
					result.of = option[2..$];
				else if (option == "-run")
					result.run = true;

				if (option != "-run") // run will be handled specially to allow for it to be used w/ multiple source files.
					result.options ~= option;
			}

			// Set the -o (output filename) flag to the first source file, if not already set.
			string ext = result.lib ? lib_ext : bin_ext; // This matches the default behavior of dmd.
			if (!result.of.length && !result.c && !result.o && sources.length)
			{	result.of = String.split(String.split(sources[0], "/")[$-1], "\\.")[0] ~ ext;
				result.options ~= ("-of" ~ result.of);
			}
			version (Windows)
			{	if (String.find(result.of, ".") <= String.rfind(result.of, "/"))
					result.of ~= bin_ext;

				//Stdout(String.find(result.of, ".")).newline;
			}
			// Exception for conflicting flags
			if (result.run && (result.c || result.o))
				throw new Exception("flags '-c', '-o-', and '-fsyntax-only' conflict with -run");

			return result;
		}

		/*
		* Translate DMD/LDC compiler options to GDC options.
		* This function is incomplete. (what about -L? )*/
		string[] getOptions(string compiler)
		{	string[] result = options.dup;

			if (compiler != "gdc")
			{
				version(Windows)
					foreach (ref option; result)
						if (String.starts(option, "-of")) // fix -of with / on Windows
							option = String.replace(option, "/", "\\");

				if (!String.contains(result, "-op"))
					return result ~ ["-op"]; // this ensures ddocs don't overwrite one another.
				return result;
			}

			// is gdc
			string[string] translate;
			translate["-Dd"] = "-fdoc-dir=";
			translate["-Df"] = "-fdoc-file=";
			translate["-debug="] = "-fdebug=";
			translate["-debug"] = "-fdebug"; // will this still get selected?
			translate["-inline"] = "-finline-functions";
			translate["-L"] = "-Wl";
			translate["-lib"] = "";
			translate["-O"] = "-O3";
			translate["-o-"] = "-fsyntax-only";
			translate["-of"] = "-o ";
			translate["-unittest"] = "-funittest";
			translate["-version"] = "-fversion=";
			translate["-w"] = "-wall";

			// Perform option translation
			foreach (ref option; result)
			{	if (String.starts(option, "-od")) // remove unsupported -od
					option = "";
				if (option =="-D")
					option = "-fdoc";
				else
					foreach (before, after; translate) // Options with a direct translation
						if (option.length >= before.length && option[0..before.length] == before)
						{	option = after ~ option[before.length..$];
							break;
						}
			}
			return result;
		}
		unittest {
			string[] sources = [cast(string)"foo.d"];
			string[] options = [cast(string)"-D", "-inline", "-offoo"];
			scope result = CompileOptions(options, sources).getOptions("gdc");
			assert(result[0..3] == [cast(string)"-fdoc", "-finline-functions", "-o foo"]);
		}
	}
}

// Log actions of functions in this module.
private struct Log
{
	static bool verbose;
	static string[] operations;

	static void add(string operation)
	{	if (verbose)
			System.trace("CDC:  " ~ operation);
		operations ~= operation;
	}
}

/// This is a brief, tango/phobos neutral system library.
struct System
{
	/**
	 * Execute execute an arbitrary command-line program and print its output
	 * Params:
	 *     command = The command to execute, e.g. "dmd"
	 *     args = Array of string arguments to pass to this command.
	 * Throws: ProcessException on failure or status code 1.
	 * TODO: Return output (stdout/stderr) instead of directly printing it. */
	static void execute(string command, string[] args=null)
	{	Log.add(command~` `~String.join(args, ` `));
		version (Windows)
			if (String.starts(command, "./"))
				command = command[2..$];

		version (Tango)
		{	/+ // hangs in Tango 0.99.9
			scope p = new Process(true);
			scope(exit)
				p.close();
			p.execute(command, args);

			Stdout.copy(p.stdout).flush; // adds extra line returns?
			Stdout.copy(p.stderr).flush;
			scope result = p.wait();
			if (result.status != Process.Result.Exit)
				throw new ProcessException(result.toString());
			+/

			string execute = command ~ " " ~ String.join(args, " ") ~ "\0";
			int status = system(execute.ptr);
			if (status != 0)
				throw new ProcessException(String.format("Process '%s' exited with status %s", command, status));
		} else		
		{
			command = command ~ " " ~ String.join(args, " ");
			bool success =  !system((command ~ "\0").ptr);
			if (!success)
				throw new ProcessException(String.format("Process '%s' exited with status 1", command));
		}
	}

	/// Get the current number of milliseconds since Jan 1 1970.
	static long time()
	{	version (Tango)
			return Clock.now.unix.millis;
		else
			return getUTCtime();
	}

	/// Print output to the console.  Uses String.format internally and therefor accepts the same arguments.
	static void trace(T...)(string message, T args)
	{	version (Tango)
			Stdout(String.format(message, args)).newline;
		else
			writefln(String.format(message, args));
	}

	/// Sleep for the given number of seconds.
	static void sleep(double seconds)
	{	version (Tango)
			Thread.sleep(seconds);
		else
		{	version (GNU)
				sleep(cast(int)seconds);
			version (D_Version2)
				sleep(cast(int)(seconds/1_000));
			else
				usleep(cast(int)(seconds/1_000_000));
		}
	}
}

/// This is a brief, tango/phobos neutral filesystem library.
struct FS
{
	/// Path separator character of the current platform
	version (Windows)
		static const string sep ="\\";
	else
		static const string sep ="/";

	/// Convert a relative path to an absolute path.
	static string abs(string rel_path)
	{	version (Tango)
			return (new FilePath).absolute(rel_path).toString();
		else
		{	// Remove filename
			string filename;
			int index = rfind(rel_path, FS.sep);
			if (index != -1)
			{   filename = rel_path[index..length];
				rel_path = replace(rel_path, filename, "");
			}

			string cur_path = getcwd();
			try {   // if can't chdir, rel_path is current path.
				chdir(rel_path);
			} catch {};
			string result = getcwd();
			chdir(cur_path);
			return result~filename;
		}
	}

	/// Set the current working directory.
	static void chDir(string path)
	{	Log.add(`cd "`~path~`"`);
		version (Tango)
			Environment.cwd(path);
		else .chdir(path);
	}

	/// Copy a file from source to destination
	static void copy(string source, string destination)
	{	Log.add(`copy "`~source~`" "`~destination~`"`);
		version (Tango)
		{	scope from = new File(source);
			scope to = new File(destination, File.WriteCreate);
			to.output.copy (from);
			to.close;
			from.close;
		}
		else
			.copy(source, destination);
	}

	/// Does a file exist?
	static bool exists(string path)
	{	version (Tango)
			return FilePath(path).exists();
		else return !!.exists(path);
	}

	/// Get the current working directory.
	static string getDir()
	{	version (Tango)
			return Environment.cwd();
		else return getcwd();
	}

	/// Is a path a directory?
	static bool isDir(string path)
	{	version (Tango)
			return FilePath(path).isFolder();
		else return !!.isdir(path);
	}

	/// Is a path a file?
	static bool isFile(string path)
	{	version (Tango)
			return FilePath(path).isFile();
		else return !!.isfile(path);
	}

	/// Get an array of all files/folders in a path.
	/// TODO: Fix with LDC + Tango
	static string[] listDir(string path)
	{	version (Tango)
		{	string[] result;
			foreach (dir; FilePath(path).toList())
				result ~= FilePath(dir.toString()).file();
			return result;
		}
		else return .listdir(path);
	}

	/// Create a directory.  Returns false if the directory already exists.
	static bool mkDir(string path)
	{
		if (!FS.exists(path))
		{
			FilePath(path).create();
			return true;
		}
		return false;
	}

	/// Argument for FS.scan() function.
	static enum ScanMode
	{	FILES = 1, ///
		FOLDERS = 2, ///
		BOTH = 3 ///
	}

	/**
	 * Recursively get all files in directory and subdirectories that have an extension in exts.
	 * This may return files in a different order depending on whether Tango or Phobos is used.
	 * Params:
	 *     directory = Absolute or relative path to the current directory
	 *     exts = Array of extensions to match
	 *     mode = files, folders, or both
	 * Returns: An array of paths (including filename) relative to directory.
	 * BUGS: LDC fails to return any results. */
	static string[] scan(string folder, string[] exts=null, ScanMode mode=ScanMode.FILES)
	{	string[] result;
		if (exts is null)
			exts = [""];
		foreach(string filename; FS.listDir(folder))
		{	string name = folder~"/"~filename; // FS.sep breaks gdc windows.
			if(FS.isDir(name))
				result ~= scan(name, exts, mode);
			if (((mode & ScanMode.FILES) && FS.isFile(name)) || ((mode & ScanMode.FOLDERS) && FS.isDir(name)))
			{	// if filename is longer than ext and filename's extention is ext.
				foreach (string ext; exts)
					if (filename.length>=ext.length && filename[(length-ext.length)..length]==ext)
						result ~= name;
		}	}
		return result;
	}

	/**
	 * Remove a file or a folder along with all files/folders in it.
	 * Params: path = Path to remove, can be a file or folder.
	 * Return: true on success, or false if the path didn't exist. */
	static bool remove(string path)
	{
		Log.add(`remove "`~path~`"`);
		if (!FS.exists(path))
			return false;
		version (Tango)
			FilePath(path).remove();
		else
			.remove(path);
		return true;
	}
	unittest {
		assert (!remove("foo/bar/ding/dong/do.txt")); // a non-existant file
		Log.operations = null;
	}
	
	static ubyte[] read(string filename)
	{	version (Tango)
			return cast(ubyte[])File.get(filename);
		else
			return cast(ubyte[])std.file.read(filename); // wonder if this works
	}

	/// Write a file to disk
	static void write(T)(string filename, T[] data)
	{	scope data2 = String.replace(String.replace(String.replace(data, "\n", "\\n"), "\r", "\\r"), "\t", "\\t");
		Log.add(`write "` ~ filename ~ `" "` ~ data2 ~ `"`);
		version (Tango)
			File.set(filename, data);
		else .write(filename, data);
	}

	// test path functions
	unittest
	{	string path = "_random_path_ZZZZZ";
		if (!FS.exists(path))
		{	assert(FS.mkDir(path));
			assert(FS.exists(path));
			assert(String.contains(FS.listDir("./"), path));
			assert(String.contains(FS.scan("./", null, ScanMode.FOLDERS), path));
			assert(FS.remove(path));
			assert(!FS.exists(path));
	}	}
}

/// This is a brief, tango/phobos neutral string library.
struct String
{
	static string changeExt(string filename, string ext)
	{
		return FilePath(filename).folder() ~ FilePath(filename).name() ~ ext;
	}
	unittest {
		assert(changeExt("foo.a", "b") == "foo.b");
		assert(changeExt("bar/foo", "b") == "bar/foo.b");
	}

	/// Does haystack contain needle?
	static bool contains(T)(T[] haystack, T needle)
	{
		return .contains(haystack, needle);
	}

	/// Find the first or last instance of needle in haystack, or -1 if not found.
	static int find(T)(T[] haystack, T[] needle)
	{	if (needle.length > haystack.length)
			return -1;
		for (int i=0; i<haystack.length - needle.length+1; i++)
			if (haystack[i..i+needle.length] == needle)
				return i;
		return -1;
	}
	static int rfind(T)(T[] haystack, T[] needle) /// ditto
	{	if (needle.length > haystack.length)
			return -1;
		for (int i=haystack.length - needle.length-1; i>0; i--)
			if (haystack[i..i+needle.length] == needle)
				return i;
		return -1;
	}
	unittest
	{	assert(find("hello world world.", "wo") == 6);
		assert(find("hello world world.", "world.") == 12);
		assert(rfind("hello world world.", "wo") == 12);
		assert(rfind("hello world world.", "world.") == 12);
	}

	/**
	 * Format variables.
	 * Params:
	 *     message = String to apply formatting.  Use %s for variable replacement.
	 *     args = Variable arguments to insert into message.
	 * Example:
	 * --------
	 * String.format("%s World %s", "Hello", 23); // returns "Hello World 23"
	 * --------
	 */
	static string format(T...)(string message, T args)
	{
		message = substitute(message, "%s", "{}");
		return Format.convert(message, args);
	}
	unittest {
		assert(String.format("%s World %s", "Hello", 23) == "Hello World 23");
		assert(String.format("foo") == "foo");
	}

	/// Join an array of strings using glue.
	static string join(string[] array, string glue)
	{	return .join(array, glue);
	}

	/// In source, repalce all instances of "find" with "repl".
	static string replace(string source, string find, string repl)
	{
		return substitute(source, find, repl);
	}

	/// Split an array by the regex pattern.
	static string[] split(string source, string pattern)
	{
		return Regex(pattern).split(source);
	}

	/// Does "source" begin with "beginning" ?
	static bool starts(string source, string beginning)
	{	return source.length >= beginning.length && source[0..beginning.length] == beginning;
	}

	/// Get the ascii lower-case version of a string.
	static string toLower(string input)
	{
		return .toLower(input);
	}

}
