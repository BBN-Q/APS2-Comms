#Run the tests in the folder
#Assumes test runner script in the xsim folder has the same name as the folder


import sys
import os
import subprocess
import glob

#Find all the directorys

script_path = os.path.dirname(os.path.realpath(__file__))
sim_paths = [x for x in os.listdir(script_path) if os.path.isdir(os.path.join(script_path, x))]

print(sim_paths)

skip = ["cpld_bridge_tb"]

any_errors = False

for sim in sim_paths:
	if sim in skip:
		continue
	print("Simulating {}".format(sim))
	os.chdir("{}/xsim".format(sim))
	try:
		sim_output = subprocess.check_output("./{}.sh".format(sim))
		#Look for errors
		lines = sim_output.decode("ascii").splitlines()
		for line in lines:
			if "Error:" in line:
				#Ignore memory collision errors
				if "Memory Collision Error" not in line:
					print(line)
					any_errors = True
	except subprocess.CalledProcessError:
		print("Simulation failed to run properly!")
		any_errors = True
	except:
		print("Unexpected error!")
		raise
	#Clean up the files
	subprocess.call(["./{}.sh".format(sim), "-reset_run"])
	files_to_delete = []
	files_to_delete.extend(glob.glob("webtalk*"))
	files_to_delete.extend(glob.glob("*.backup.*"))
	for f in set(files_to_delete):
		if os.path.isfile(f):
			os.remove(f)
	os.chdir(script_path)

if any_errors:
	sys.exit(1)
else:
	sys.exit(0)
