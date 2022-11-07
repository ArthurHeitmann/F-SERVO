from dataclasses import dataclass
import importlib.util
import subprocess
import sys


@dataclass
class PythonDependency:
	moduleName: str
	pipName: str

pythonDependencies = [
	PythonDependency("PIL", "pillow"),
	PythonDependency("fontTools", "fonttools"),
]

def checkPythonDependency(dependency: PythonDependency) -> bool:
	try:
		if not importlib.util.find_spec(dependency.moduleName):
			print(f"Module {dependency.moduleName} not found, installing...")
			subprocess.check_call(["python", "-m", "pip", "install", dependency.pipName])
			print(f"Module {dependency.moduleName} installed.")
		return True
	except Exception as e:
		print(f"Error while installing {dependency.moduleName}: {e}")
		return False

def checkPythonDependencies() -> bool:
	return all(checkPythonDependency(dependency) for dependency in pythonDependencies)

if __name__ == "__main__":
	res = checkPythonDependencies()
	if not res:
		print("Failed to install dependencies, exiting...")
		sys.exit(1)
