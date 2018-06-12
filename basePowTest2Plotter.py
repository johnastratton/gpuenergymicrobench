import pylab
import pandas
from matplotlib.backends.backend_pdf import PdfPages
import glob

'''
helpful styling guide:

http://www.randalolson.com/2014/06/28/how-to-make-beautiful-data-visualizations-in-python-with-matplotlib/
'''

##constants
SAVE_DPI = 1000
LINE_WIDTH = 0.4
MAX_Y = 70

colors = ['b', 'g', 'r', 'c', 'm', 'y', 'k', "tab:grey"]



#given filepath, return list of power data as FPs
def getPowerFromFile(filePath):
	colnames = ['power', 'temp', 'time', 'totalT', 'totalSamples']
	data = pandas.read_csv(filePath, names=colnames, encoding='utf-8')

	power = data.power.tolist()[1:]
	power = [float(power[i]) for i in range(len(power))]
	return power

#name of test to make graph for
#  ex: FMAFP32, FMAFP64, AddInt32, MultFP32...
def makeFigure(testPathTups):
	powerLists = []
	for i in range(len(testPathTups)):
		powerLists.append(getPowerFromFile(testPathTups[i][0]))

	f = pylab.figure()
	ax = pylab.subplot(111)    
	ax.spines["top"].set_visible(False)    
	ax.spines["right"].set_visible(False)    
	
	for i in range(len(powerLists)):
		pylab.plot(range(len(powerLists[i])), powerLists[i], colors[i], label="workload of "+str(i+1)+"x", lw=LINE_WIDTH)

	pylab.xlabel('time(ms)')
	pylab.ylabel('power(W)')
	pylab.suptitle("Base Power 2nd Approach Runs")
	pylab.title("Linearly changing number of blocks per run", fontsize=8)

	pylab.legend(loc="lower right")
	pylab.ylim(0, MAX_Y)

	#save to seperate file
	# f.savefig("data/"+ testStr + ".pdf", bbox_inches='tight')

	return f

#input: list of test strings to make graphs for
#  ex: ["FMAFP32", "AddInt32"]
#output: list of plots. One plot per input element
def getListOfPlots(listOfTests):
	out = []
	for test in listOfTests:
		out.append(makeFigure(test))
	return out

#given a file name to save to, and a list of figures, save to one pdf
def saveFigureList(figs, filePath):
	pp = PdfPages(filePath)
	for fig in figs:
		pp.savefig(fig, dpi=SAVE_DPI)
	pp.close()





testPathTups = glob.glob("data/basePow2/*.csv")
for i in range(len(testPathTups)):
	name = testPathTups[i].replace("data/basePow2/output", "").replace(".csv", "")
	testPathTups[i] = (testPathTups[i], name)

fig = makeFigure(testPathTups)
fig.savefig("data/basePow2/graphResultsBasePow2.pdf", dpi=SAVE_DPI)










