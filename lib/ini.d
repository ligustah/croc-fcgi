module lib.ini;

import tango.io.device.File;
import tango.text.convert.Layout;
import tango.io.device.Conduit;
import tango.io.FilePath;
import Text = tango.text.Util;
import Integer = tango.text.convert.Integer;


class IniSection
{
	private char[][char[]] _data;
	private static Layout!(char) layout;
	
	static this()
	{
		 layout = Layout!(char).instance();
	}
	
	public char[] getString(char[] key, char[] def = null)
	{
		char[] val = get(key);
		
		return (val && val.length) ? val : def;
	}
	
	public long getInt(char[] key, long def = 0)
	{
		char[] val = get(key);
		
		return (val) ? Integer.parse(val) : def;
	}
	
	public bool getBool(char[] key, bool def = false)
	{
		char[] val = get(key);
		
		return (val) ? (val == "1" || val == "true") : def;
	}
	
	public bool has(char[] key)
	{
		return get(key) != null;
	}
	
	/**
		char[] key - the key to search for
		
		returns the value of the given key or null if the key is not found
	*/
	public char[] get(char[] key)
	{
		if(!(key in _data))
			return null;
		return _data[key];
	}
	
	template set(T)
	{
		public void set(char[] key, T value)
		{
			this._data[key] = layout("{}", value);
		}
	}
	
	void save(OutputStream output)
	{
		foreach(key, value; this._data)
		{
			if(key.length)
				output.write(layout("{} = {}\r\n", key, value));
		}
	}
	
	void optimize()
	{
		this._data = this._data.rehash;
	}
	
	template opIndexAssign(T)
	{
		public void opIndexAssign(T value, char[] key)
		{
			set(key, value);
		}
	}
	
	public alias getString opIndex;
}

class Ini
{
	private IniSection[char[]] _sections;
	private char[] _fileContents;
	
	
	public this(char[] file)
	{
		load(file);
	}
	
	public this()
	{
		
	}
	
	public void load(char[] file)
	{
		if(FilePath(file).exists)
		{
			File f = new File(file);
			load(f);
			f.close();
		}
	}
	
	public void save(char[] file)
	{
		File f = new File(file, File.WriteCreate);
		save(f);
		f.close();
	}
	
	void load(InputStream input)
	{
		char[] contents = cast(char[]) input.load;
		
		if(contents.length)
		{
			_fileContents = contents;
			parse();
		}
	}
	
	void save(OutputStream output)
	{
		output.write("; automatically generated file\r\n");
		
		if("" in _sections)
		{
			_sections[""].save(output);
		}
		
		foreach(name, section; _sections)
		{
			if(name.length)
			{
				output.write("[" ~ name ~ "]\r\n");
				section.save(output);
			}
		}
	}
	
	void parse()
	{
		IniSection[char[]] sections;
		IniSection s;
		
		
		IniSection section(char[] name)
		{
			if(!(name in sections))
			{
				sections[name] = new IniSection();
			}
			return sections[name];
		}
		
		s = section("");
		
		foreach(line; Text.splitLines(this._fileContents))
		{
			line = Text.trim(line);
			
			if(!line.length)
				continue;
			
			char c = line[0];
			
			if(c == ';' || c == '#') // ignore comments
				continue;
			
			if(c == '[') // new section
			{
				int pos = Text.locate(line, ']', 1);
				
				if(pos == line.length) // malformed section declaration
					continue;
				
				char[] secName = Text.trim(line[1..pos]);
				
				s = section(secName);
				continue;
			}
			
			int pos = Text.locate(line, '=');
			
			if(pos == line.length)	//malformed key
				continue;
			
			char[] key = Text.trim(line[0..pos]);
			char[] value = Text.trim(line[pos + 1..$]);
			
			if(!key.length)	// empty key
				continue;
				
			s.set(key, value);
		}
		
		foreach(name, section; sections)
		{
			section.optimize();
		}
		
		this._fileContents = null;
		this._sections = sections.rehash;
	}
	
	public bool hasSection(char[] name = "")
	{
		return (name in _sections) ? true : false;
	}
	
	public IniSection getSection(char[] name = "")
	{
		if(!hasSection(name))
		{
			_sections[name] = new IniSection();
		}
		return _sections[name];
	}
	
	public alias getSection section;
	
	public IniSection opIndex(char[] name)
	{
		return getSection(name);
	}
	
	public void remove(char[] name)
	{
		if(hasSection(name))
			this._sections.remove(name);
	}
	
	public void opIndexAssign(char[] key, char[] value)
	{
		assert(false, "Ini is read-only");
	}
	
	public int opApply(int delegate(inout char[], inout IniSection) dg)
	{
		int result = 0;
		foreach(name, section; _sections)
		{
			result = dg(name, section);
			if(result)
				break;
		}
		
		return result;
	}
	
	public int length()
	{
		return _sections.length;
	}
}