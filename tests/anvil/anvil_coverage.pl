# USAGE: Place in base directory of Anvil and execute. api.jsca must be in the same directory.
#
# PURPOSE:
#
# Read all Anvil source files and compile a list of all Titanium calls made in the Anvil
# source files, in order to determine the statistics of Titamium functionality coverage in Anvil.
#
# INPUT:
#
# - Anvil source files
# - api.jsca file
#
# OUTPUT: 
#
# - "anvil_all_references.txt" - list of references to all Titanium methods and properties that are called
#   inside the source files.
# - "titanium_all_symbols.txt" - list of all Titanium methods and properties, in the "Ti.XXXX.YYYY" format.
# - "anvil_coverage_stats.txt" - list of all Titanium namespaces, with Anvil coverage statistics (sorted
#   from least coverage to best coverage.
#
# NOTE:
# - Anvil source code parsing is only so accurate. The parser tries to resolve types of variables to infer
#   calls, but it is not 100% accurate. The data is for general guidance, not exact calculations.
# - When calculating coverage, the scipt is not aware that some properties and methods were inherited 
#   from base namespaces.


use File::Find;
use File::Basename;
use Cwd;
use Data::Dumper;
use JSON;
use List::Util qw(first);
#use warnings;
#use strict;


#1 Global data

# Intermediate list of all Titanium calls in Anvil. May contain items like Ti.Filesystem.getfile.size instead
# of Ti.Filesystem.File.size; correct types are resolved later.
my %calls = ();         

my $files = 0;                          # counter of processed files
my $countFunctionsAndProperties = 0;    # counter of processed properties

my $jsca;                               # Titanium JSCA file as a perl object

my $superclasses;

# All Titanium functions and properties.
# Hash: "Ti.XXXX.YYYY" --> "Ti.AAAA.BBBB", where Ti.XXXX.YYYY is a function/property,
# and Ti.AAAA.BBBB is its return type. Only for functions/properties that have
# Titanium return types (i.e. String/Number returning functions/properties are ignored).
# Parsed out of the JSCA file.
my %jscaFunctionsAndProperties = ();

# All Titanium types in the format Ti.XXXX.YYYY.
my %jscaTypes = ();

# All Titanium entities (functions, properties, namespaces, etc) in the format Ti.XXXX.YYYY.
my %jscaAll = ();

# Hash: { Titanium Type } --> { array of types it inherits from, including all grand-ancestors }
my %inheritance = ();

# Hash: Titanium namespace -> Number of properties and functions in the namespace.
# For all Titanium namespaces.
# Purpose: generation of Anvil coverage stats.
my %jscaTypesMembers = ();

# Hash: Titanium namespace -> Number of properties and functions of that namespace, referenced in Anvil.
# For all Titanium namespaces. 
# Purpose: generation of Anvil coverage stats.
my %anvilTypesMembers = ();

#All Titanium namespaces that appear in inheritance tree
my @allNamespaces;

my %formatedInherited;

# FIXME !!!
my %hash;


# ============================================================================== #

#1 Main logic

open DEBUG, ">debug.txt";
my $dir = getcwd();


#2 Read and parse JSCA

print "\nReading JSCA...\n";

my $jsca_content = do {
    local $/ = undef;
    open JSCA, "api.jsca" or die "could not open $file: $!";
    <JSCA>;
};
print "     Read " . length($jsca_content) . " bytes\n";

my $superclasses_content = do {
	local $/ = undef;
	open SUPERCLASSES, "superclasses.json" or die "could not open $file $!";
	<SUPERCLASSES>
};

$superclasses = decode_json($superclasses_content);



print "\nParsing JSCA (20 seconds)...\n";
$jsca = decode_json($jsca_content);



#2 Remove inherited entities from $jsca

print "Reading inheritance info...\n";
getInheritanceInfo();

print "\nRemoving inherited entities...\n";
removeInheritedTypes();


print "\nRemoving non-MobileWeb entities...\n";
removeNonMobileWeb();

#2 Generate intermediate structures from $jsca

print "\nAnalyzing JSCA...\n";
genJscaFuncDictionary();
print "     Found $countFunctionsAndProperties functions and properties\n";

#print Dumper (\%calls);

print "\nRemoving setters and getters for tested properties\n";


#2 Parse Anvil source code and generate a list of references to Titanium

my $dir = getcwd();

print "\nParsing Anvil source code...\n";
find(\&process, $dir);
print "     Parsed $files files\n";
print "     Found references to " . scalar(keys %calls) . " entities \n";

unifyPropertyCalls();

open ALLANVIL, ">anvil_all_references.txt";
foreach $call(sort keys %calls)
{
    print ALLANVIL "$call\n";
}

#(%calls <---> %jscaXXXXX)

#2 Count Anvil references

print "\nGenerating stats...\n";

# To know Anvil coverage statistics, for each namespace, we compare the number of methods and properties
# referenced in Anvil to the total number of methods and properties in Titanium.

foreach $type(keys %jscaTypesMembers)
{
    $anvilTypesMembers{$type} = 0;
}

# Count how many methods and properties were referenced for each type. (O(n*n))

foreach $call(keys %calls)
{
    # don't count references to pure types; only count references to methods and functions.
    if(defined($jscaTypes{$call}))
    {
        next;
    }
    
    foreach $type(keys %jscaTypesMembers)
    {
        if($call =~ m/$type\.[a-zA-Z0-9_]+$/)
        {
            $anvilTypesMembers{$type}++;
        }
    }
}

# Sort by frequency

my %frequencies = ();

foreach $type(sort keys %anvilTypesMembers)
{
    if($jscaTypesMembers{$type}==0)
    {
        next;
    }    $frequencies{$anvilTypesMembers{$type}/$jscaTypesMembers{$type}} = $frequencies{$anvilTypesMembers{$type}/$jscaTypesMembers{$type}} . " $type";
}

# Write out

open(OUTPUT, ">anvil_coverage_stats.txt");
foreach $frequency(sort keys %frequencies)
{
    print OUTPUT $frequency . ": \n";
    my @tmptypes = split(/ /, $frequencies{$frequency});
    foreach $tmptype(@tmptypes)
    {
        print OUTPUT "       " . $tmptype . "\n" unless $tmptype eq '';
    }
    print OUTPUT "\n";
}

# Write out all Titanium references

open ALLJSCAF, ">titanium_all_symbols.txt";
open NONCOVERED, ">anvil_not_covered.txt";
foreach $jscaprop(sort keys %jscaAll)
{
    print ALLJSCAF "$jscaprop\n";
    if(!defined($calls{$jscaprop}))
    {
        print NONCOVERED "$jscaprop\n";
    }
}


# end of script



# =========================================================================================== #

#1 Get inheritance info

sub getInheritanceInfo()
{
#get all parent namespaces recursively
    sub get_all_parent_namespaces
    {
    	my $val = $_[0];
    	
    	$val =~ s/\//\./g;
    	$val =~ s/["']+//g;
    	
    	my $new_val = $hash{$val};
    	
    	if ($new_val ne "")
    	{
    		$val = $val . " => " . get_all_parent_namespaces($new_val);
    	}
    	else
    	{
    		$val
    	}
    }

    my $dir = "c:/Users/Roman.Kamenetskyi/AppData/Roaming/Titanium/mobilesdk/win32/3.0.1.v20121218130634/mobileweb/titanium/";
	if (!(-d $dir)) {
		print "\nError:\n";
		print "Cannot find directory with SDK\n";
		exit;
	}
    my @files = ();

    my $file_pattern = ".*js";

    #Content of the file
    my $content;
    #Variable for storing namespace. It will be key of the resulting hash
    my $key;
    #Parent naespace for given namespace. It will be the value of hash
    my $value;
    #Parent object for current  namespace
    my $parent;
    #Array of all namespaces from define function
    my @namespaces;
    #All objects representing namespaces from define function
    my @objects;
    my $index;


    find(sub{ push @files, $File::Find::name if (m/^(.*)$file_pattern$/) }, $dir);

    foreach my $file (@files) 
    {
    	open(my $fh, '<', $file) or die "cannot open file $file";
    	{
            local $/;
            $content = <$fh>;
    		
    		#remove all new lines and tabs for easier parsing
    		$content =~ s/\n\t//g;
    		#find declaring new namespace and its parent
    		if ($content =~ m/declare\(["']((.)*?)["'],[ ]([A-Za-z_]*?)(,|\))/)
    		{
    			$key = $1;
    			$parent = $3;
    		} 
    		#if declare is not used try to find setObject with new namespace and its parent
    		elsif ($content =~ m/lang\.setObject\(["']((.)*?)["'],[ ]*?([A-Za-z_]*?)(,|\)|\{)/)
    		{
    			$key = $1;
    			$parent = $3;
    		}
    		else
    		{
    			$key = "";
    			$parent = "";
    		}
    		#parsing namespaces in define function and appropriate objects
    		if ($content =~ m/define\(\[((.)*?)\].*?function\(((.)*?)\)/)
    		{
    			@namespaces = split(',', $1);
    			@objects = split(', ', $3);
    		}
    		else
    		{
    			$namespaces = "";
    			$objects = "";
    		}
    	}
		
		#print "@namespaces\n";
    	#if file creates new namespace then find its parent namespace
    	if (($key ne "") && ($parent ne "null") && ($parent ne "")) 
    	{
    		#next two rows find parent namespace for given one
    		$index = first { $objects[$_] eq $parent } 0..$#objects;		
    		$value = @namespaces[$index];
    		#remove spaces
    		$value =~ s/[ ]*//g;
    		#save namespaces into hash in format namespace => its parent
    		$hash{$key} = $value;
    	}
    	close($fh);	
    }

	#print Dumper(\%hash);
	
#loop through all namespaces and find all parents
    foreach my $k (keys %hash)
    {
    	my $res = get_all_parent_namespaces($hash{$k});
    	$inheritance{$k} = [split(" => ", $res)];
    }
}


#1 Process JSCA

sub removeInheritedTypes()
{
    sub getAllNamespacesFromInheritance()
    {
    	#array of parents for each namespace
    	my @parents;
    	my $index;
    	
    	foreach my $namespace (keys %inheritance)
    	{
    		#Adding namespaces if the don't exist in array
    		$index = first { $allNamespaces[$_] eq $namespace } 0..$#allNamespaces;	
    		push(@allNamespaces, $namespace) if ($index eq "");
    		
    		#Adding parents if they don't exist in array
    		@parents = @{$inheritance{$namespace}};
    		foreach my $parent (@parents)
    		{
    			$index = first { $allNamespaces[$_] eq $parent } 0..$#allNamespaces;	
    			push(@allNamespaces, $parent) if ($index eq "");
    		}
    	}
    }

    sub createFormatedHash()
    {
    	#All titanium types
    	my @types = @{$jsca->{types}};
    	#Titanium namespace
    	my $name;
    	my $index;
    	my %type;
    	
    	my %tempObj = ();
    	
    	for my $i(0 .. $#types)
    	{
    		%type = %{$types[$i]};
    		#Get namespace name
    		$name = $type{name};
    		$name =~ s/Titanium/Ti/;
    		$index = first { $allNamespaces[$_] eq $name } 0..$#allNamespaces;	
    		$formatedInherited{$name} = {properties => $type{properties}, functions => $type{functions}, index => $i} if ($index ne "");
    	}
    	#print Dumper(\%formatedInherited);
    }
	
	my %super_properties = ();
	my %super_functions = ();
	
	#create and fill list with properties from superclass
	foreach my $prop (@{$superclasses->{properties}})
	{
		
		$super_properties{$prop->{name}} = " ";
	}
	
	#create and fill list with methods from superclass
	foreach my $func (@{$superclasses->{functions}})
	{
		
		$super_functions{$func->{name}} = " ";
	}		
	
	# Removes methods and properties from superclasses.json 
	# (in case the inheritance information is incomplete, this file allows to specify a "virtual ancestor"
	# for all Titanium namespaces).
	sub removeSuperProperties
	{
		my @types = @{$jsca->{types}};
		#all properties for current namespace
		my @properties = [];
		#all functions for current namespace
		my @functions = [];
		#property or function name
		my $name = "";
		my $namespace = "";
		my $i = -1;
		my $j = 0;
		foreach my $type (@types)
		{
			$i++;
			$namespace = $type->{name};
			if(!($namespace =~ s/Titanium\./Ti./))
			{
				next;
			}

			@properties = @{$type->{properties}};
			@functions = @{$type->{functions}};
			$j = -1;
			foreach my $property(@properties)
			{
				$j++;
				$name = $property->{name};
				#if property is inherited from superclass - remove it
				if (exists $super_properties{$name})
				{
					delete $jsca->{types}[$i]->{properties}[$j];
				}
			}
			
			$j = -1;
			foreach my $function(@functions)
			{
				$j++;
				$name = $function->{name};
				#if method is inherited from superclass - remove it
				if (exists $super_functions{$name})
				{
					delete $jsca->{types}[$i]->{functions}[$j];
				}
			}			
		}

	}
	
	

    getAllNamespacesFromInheritance();
    createFormatedHash();

	my @parents;
	my %obj;
	#All properties of the object
	my @properties;
	#All functions of the object
	my @functions;	
	#Property object
	my %property;
	#Function object
	my %function = ();
	#All propreties of parent obj
	my @parent_properties = [];
	#All functions of parent obj
	my @parent_functions = [];
	#Property object of parent obj
	my %parent_property = ();
	#Function object of parent obj
	my %parent_function = ();
	my $name = "";
	my $parent_name = "";
	my $index = 0;
	
	
	removeSuperProperties();
	
	my @types = @{$jsca->{types}};
	
	foreach my $key(keys %inheritance)
	{
		@parents = @{$inheritance{$key}};
		%obj = %{$formatedInherited{$key}};
		#All propreties of namespace
		@propreties = @{$obj{properties}};
		#Allfunctions of the namespace
		@functions = @{$obj{functions}};
		#Index of namespace in JSCA
		$index = $obj{index};
		for my $i(0 .. $#propreties)
		{
			%property = %{$propreties[$i]};
			$name = $property{name};
			
			#loop through all pparents
			foreach my $parent (@parents)
			{
				%obj = %{$formatedInherited{$parent}};
				#get parent properties
				@parent_properties = @{$obj{properties}};
				#loop through all parent properties
				for my $j(0 .. $#parent_properties)
				{
					%parent_property = %{$parent_properties[$j]};
					#if property is inherited - remove it
					if (($name eq $parent_property{name}) or (exists $super_properties{$name}))
					{
						my %o = %{$types[$index]};
						delete $o{properties}[$i];
						goto AFTER_PROPERTIES;
					}
				}
			}
			AFTER_PROPERTIES:
		}
		#looping through all functions
		for my $i(0 .. $#functions)
		{
			%function = %{$functions[$i]};
			$name = $function{name};
			
			#Looping through parents
			foreach my $parent (@parents)
			{
				%obj = %{$formatedInherited{$parent}};
				@parent_functions = @{$obj{functions}};
				#find all parent functions
				for my $j(0 .. $#parent_functions)
				{
					%parent_function = %{$parent_functions[$j]};
					
					#if function is inherited - remove it
					if (($name eq $parent_function{name}) or (exists $super_functions{$name}))
					{
						my %o = %{$types[$index]};
						delete $o{functions}[$i];
						goto AFTER_FUNCTIONS;
					}
				}
			}
			AFTER_FUNCTIONS:
		}		
	}
}

# If reference to Ti.x are referenced (where x is a property), assume Ti.getX and Ti.getX are also referenced.
# If reference to either Ti.getX or Ti.setX is referenced, assume Ti.x is also referenced.
# (Referenced = is contained in %calls.)
sub unifyPropertyCalls()
{
	my (@properties, @functions);
	my (%property, %function);
	my ($name, $namespace, $getter, $setter);
	@properties = @functions = [];
	%property = %function = ();
	$name = $namespace = $getter = $setter = "";
	my @types = @{$jsca->{types}};
		
	foreach my $type (@types)
	{
		$namespace = $type->{name};

        if(!($namespace =~ s/Titanium\./Ti./))
        {
            next;
        }		
		@properties = @{$type->{properties}};
		@functions = @{$type->{functions}};

		foreach $property (@properties)
		{	
			$name = $namespace . "." . $property->{name};
			$getter = $namespace . ".get" . ucfirst($property->{name});
			$setter = $namespace . ".set" . ucfirst($property->{name});

			#if property is tested then add getter and setter
			if (exists $calls{$name})
			{
				if(defined($jscaAll{$getter}))
				{
					$calls{$getter} = " ";
				}
				if(defined($jscaAll{$setter}))
				{
					$calls{$setter} = " ";
				}				
			}
			#if getter exists then add proprety
			elsif (exists $calls{$getter})
			{
				$calls{$name} = " ";
				#if proprty is not readonly - add setter
				if (defined($jscaAll{$setter}))
				{
					$calls{$setter} = " ";
				}
			}
			#if setter exists - add property and getter
			elsif (exists $calls{$setter})
			{
				$calls{$name} = " ";
				$calls{$getter} = " ";
			}
		}
	}
}


# Remove non-MobileWeb types, properties and methods from %jsca.
# Sets members of $jsca->types array to undef if they are not advertising
# MobileWeb support.

sub removeNonMobileWeb()
{
    sub isMW
    {
        my $hash = $_[0];
        my @useragents = @{$hash->{userAgents}};
        foreach $useragent(@useragents)
        {
            my $useragentstring = ${$useragent}{platform};
            #print DEBUG "      usaragent=$useragentstring\n";
            if($useragentstring eq 'mobileweb')
            {
                return 1;
            }
        }
        return 0;
    }

    my @types = @{$jsca->{types}};
    my $i = -1;
    foreach $type(@types)
    {
        $i++;
        my $typename = $type->{name};
        if(!($typename =~ s/Titanium\./Ti./))
        {
            next;
        }

        if(isMW($type)==0)
        {
            ${$jsca->{types}}[$i] = undef;
            #print DEBUG "         Deleted non-MW: $typename\n";
            next;
        }

        # This type supports MobileWeb. Now, filter its methods and properties that don't.
        my @properties = @{$type->{properties}};
        my $j = -1;
        foreach $property(@properties)
        {
            $j++;
            if(isMW($property)==0)
            {
                delete ${$jsca->{types}}[$i]->{properties}[$j];
            }
        }

        my @functions = @{$type->{functions}};
        $j = -1;
        foreach $function(@functions)
        {
            $j++;
            if(isMW($function)==0)
            {
                delete ${$jsca->{types}}[$i]->{functions}[$j];
            }
        }
    }
}


# Generate %jscaFunctionsAndProperties from $jsca

sub genJscaFuncDictionary()
{
    #print DEBUG "genJscaFuncDictionary\n";
    my @types = @{$jsca->{types}};
    my $typecount = 0;

    foreach $type(@types)
    {
        if(defined($type))
        {
            $typecount++;
            parseType($type);
        }
    }
    print "     Found $typecount types\n";
}


# genJscaFuncDictionary() worker

sub parseType()
{
    my %type = %{shift};
    my $typename = $type->{name};
    if(!($typename =~ s/Titanium\./Ti./))
    {
        return;
    }
    $jscaTypes{$typename} = ' ';
    $jscaTypesMembers{$typename} = 0;

    my @properties = @{$type->{properties}};

    foreach $property(@properties)
    {
        if(!defined($property))
        {
            next;
        }
        $countFunctionsAndProperties++;
        my $proptype = $property->{type};
        if (index($proptype,"Titanium.") != -1)
        {
            # This is a property that returns a Titanium object.
            my $propname = $type->{name} . "." . $property->{name};
            $propname =~ s/Titanium\./Ti./;
            $proptype =~ s/Titanium\./Ti./;
            $jscaFunctionsAndProperties{$propname} = $proptype;
        }

        my $propname = $type->{name} . "." . $property->{name};
        $propname =~ s/Titanium\./Ti./;
        $jscaAll{$propname} = " ";
        $jscaTypesMembers{$typename}++;
    }

    my @functions = @{$type->{functions}};

    foreach $function(@functions)
    {
        if(!defined($function))
        {
            next;
        }
        $countFunctionsAndProperties++;
        my @functypes = @{$function->{returnTypes}};
        my $return_types = scalar(@functypes);

        # Functions can return several different types. Find a Titanium type among them.
        foreach $functype(@functypes)
        {
            my $functypename = $functype->{type};
            if (index($functypename,"Titanium.") != -1)
            {
                # This is a function that returns a Titanium object.
                my $funcname = $type->{name} . "." . $function->{name};
                $funcname =~ s/Titanium\./Ti./;
                $functypename =~ s/Titanium\./Ti./;
                $jscaFunctionsAndProperties{$funcname} = $functypename;
                last;
            }
        }
        my $funcname = $type->{name} . "." . $function->{name};
        $funcname =~ s/Titanium\./Ti./;
        $jscaAll{$funcname} = " ";
        $jscaTypesMembers{$typename}++;
    }
}


#1 Process Anvil source code


# Process an ANvil source file.

sub process
{
    my $file = $_;
    if($file eq '.' || $file eq '..')
    {
        return;
    }    if($file =~ m/\.js$/)
    {
        processjs($File::Find::name);
		findAllProp($File::Find::name);
    }
}

# Find all properties set in creators in Anvil tests
# like this:
# Ti.UI.createActivityIndicator({
#		  color: '#00ff00',	
#		  backgroundColor: '#00ffff',
#		});
# and add them to list of all anvil calls
# (for example: Ti.UI.ActivityIndicator.color, Ti.UI.ActivityIndicator.backgroundColor).
# It also adds getters and setters (if exist) for found properties to the list of anvil

sub findAllProp
{
	my $path = shift;
	my $content = "";
	my $param_str = "";
	my $i = -1;
	my $type = ""; #Titanium type for creator
	#Array of all properties that are set in object creator
	my @properties = [];
	# All params passes to creator
	my @params = [];
	#setter for property
	my $setter = "";
	#getter for property
	my $getter = "";
	
	open(my $fh, '<', $path) or die "cannot open file $path";
	{
		local $/;
		$content = <$fh>;	
		# Remove line comments
		$content =~ s/[^:]\/\/.*//g;
		# Remove tabs
		$content =~ s/[\t]*//g;
		# Remove new lines
		$content =~ s/[\n]*//g;
		# Remove spaces
		$content =~ s/[ ]{1,}//g;
		
		# Check for consrtuctions like this: = Ti.XXXX.YYYY.createYYYY({params})
		
		while ($content =~ /=\s*?(Ti\.[a-zA-Z0-9_.]*)\({(.*?)}\)/g)
		{
			$i++;
			if (($1 eq "") or ($2 eq ""))
			{
				next;
			}
			if (defined($jscaFunctionsAndProperties{$1}))
			{
				$type = $jscaFunctionsAndProperties{$1};
				$param_str = $2;
				$param_str =~ s/{[a-zA-Z0-9_.,'":]*?},/object_str,/g;
				@params = split(",", $param_str);
				foreach my $param (@params)
				{
					@properties = split(":", $param);
					if (isMWProperty($type,  $properties[0]) == 0)
					{
						next;
					}
					$setter = $type . ".set" . ucfirst($properties[0]);
					$getter = $type . ".get" . ucfirst($properties[0]);
					$calls{$type . "." . $properties[0]} = " ";
					if(defined($jscaAll{$getter}))
					{
						$calls{$getter} = " ";
					}
					if(defined($jscaAll{$setter}))
					{
						$calls{$setter} = " ";
					}				
				}				
			}
		}
	}
	
	# Check if property is MobileWeb property
	# First parameter namespace, second parameter - property name
	# Returns 1 if it is MW property, otherwise returns 0
	sub isMWProperty
	{
		my @types = @{$jsca->{types}};
		my (@properties, @user_agents);
		my @properties = @user_agents = [];
		my %user_agent = ();
		my ($namespace, $platform);
		$namespace = $platform = "";
		my $property_name = $_[1];
		foreach my $type(@types)
		{
			$namespace = $type->{name};

			if(!($namespace =~ s/Titanium\./Ti./))
			{
				next;
			}
			if ($namespace ne $_[0])
			{
				next;
			}
			@properties = @{$type->{properties}};
			foreach my $property(@properties)
			{
				if (!defined($property))
				{
					next;
				}
				if ($property->{name} ne $property_name)
				{
					next;
				}
				@user_agents = @{$property->{userAgents}};
				foreach $user_agent (@user_agents)
				{
					$platform = $user_agent->{platform};
					if ($platform eq "mobileweb")
					{
						return 1;
					}
				}
				return 0;
			}
		}
		return 0;
	}
	
}	
	
# Process an ANvil source file (process() worker)

sub processjs()
{
    # Process a JavaScript source file.
    # Find all references to Titanium namespaces, properties and methods,
    # and add them to the %calls list.
    # Processing is sophisticated: for example, the following code will be processed
    # as expected:
    #
    # var x = Ti.UI.createButton();
    # x.label = "hello";
    #
    # In this case, the script will report that Ti.UI.Button.label is referenced 
    # (covered by tests).

    my $path = shift;
    #print DEBUG "\n\n$path\n\n";
    my %variables = ();
    $files++;

    open(JS, $path) or return;

    foreach $line (<JS>)  
    {   
        chomp($line);
        $line =~ s/Titanium\./Ti./g;
        
        if($line =~ m/(Ti\.[a-zA-Z0-9_.]*)/)
        {
            # This is a simple reference to a Titanium namespace, function or property.
            # Add it to the list of references.
            if(defined($jscaAll{$1}) || defined ($jscaTypes{$1}))
            {
                $calls{"$1"} = " ";
            }
            else
            {
                #print DEBUG "Garbage: $1\n";
            }
        }
        
        if($line =~ m/([a-zA-Z0-9_]*)\s?=\s?(Ti\.[^( ;]*)/ && $1 ne '')
        {
            # This is an *assignment operation*, where on the right there is a reference
            # to a Titanium namespace, function or property, and on the left, the variable name.
            # The goal of this block is to remember the type of the variable, so that if it's references
            # later, we know its type and can resolve the statement properly.
            
            if(defined($jscaFunctionsAndProperties{$2}))
            {
                my $type = $jscaFunctionsAndProperties{$2};
                $variables{$1} = $type;
                $calls{$type} = " ";
            }
        }

        foreach $var(sort keys %variables)
        {
            if($line =~ m/$var\.([a-zA-Z0-9_]*)/)
            {
                # This is a reference to a function or a property of a previously declared variable.
                # Resolve the type of the variable, and remember the reference.
                
                my $type = "$variables{$var}.$1";
                if(defined($jscaAll{$type}) || defined ($jscaTypes{$type}))
                {
                    $calls{$type} = " ";
                }
                else
                {
                }
            }

            if($line =~ m/([a-zA-Z0-9_]*)\s?=\s?$var\.([a-zA-Z0-9_]*)/ && $1 ne '')
            {
                #print DEBUG "recursive var in: $line\n";
                
                # This is an *assignment operation*, where on the right there is a reference
                # to a previously declared variable, plus a call.
                # For example, variable "db" may have been declared previously like this:
                # var db   = Ti.Database.open('Test');
                # and now we're processing the following line:
                # resultSet = db.execute('SELECT * FROM stuff');
                # In this block, we know that db's type is Ti.Database.DB, and the return type
                # of execute is Ti.Database.ResultSet, so we remember that resultSet's type is
                # Ti.Database.ResultSet. 

                my $tmp = "$variables{$var}.$2";
                my $type = $jscaFunctionsAndProperties{$tmp};
                if(defined ($jscaTypes{$type}))
                {
                    #print DEBUG "    var $1 = $type;\n";
                    $variables{$1} = $type;
                }
                else
                {
                    #print DEBUG "     Garbage: var $1 = $type;\n";
                    #print DEBUG "    (type of $var is " . $variables{$var} . ")\n";
                }
            }
        }
    }
}

