package ite.trace.processing.traceConfig.decompress;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

import ite.trace.processing.CsvTraceWriter;
import ite.trace.processing.TraceWriter;
import ite.trace.processing.traceConfig.tracer.Tracer;
import ite.trace.processing.traceConfig.tracerInstance.TracerInstance;
import ite.trace.util.BitReader;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidLengthException;
import ite.trace.exceptions.InvalidTraceException;

/**
 * Decompress trace.
 * 
 * @author Stefan Alex
 * 
 */
public class DecompressCtrl {

	private static final boolean check = false;
	
	/**
	 * Decompress a trace, given by the <code>BitReader</code> and the steam
	 * behind it, and write it to the csv-file
	 * 
	 * @param br
	 *            the trace
	 * @param tracer
	 *            the tracer in right coding-order.
	 * @param outFile
	 *            the output-file
	 * @param cycleAccurate
	 *            cycle-accurate trace
	 * @param timeBits
	 * 
	 * @throws IOException
	 * @throws InvalidTraceException
	 * @throws InvalidLengthException
	 */
	public static void decompress(BitReader br, List<Tracer> tracer,
			File outFile, boolean cycleAccurate, int timeBits)
			throws IOException, InvalidTraceException, InvalidLengthException {

		List<TracerInstance> tracerInstances = new ArrayList<TracerInstance>();

		for (Tracer t : tracer) {
			tracerInstances.addAll(t.getInstances());
		}

		for (TracerInstance t : tracerInstances) {
			t.setBitReader(br);
		}

		// create Dest-File-Writer
		TraceWriter tw = new CsvTraceWriter(outFile, tracerInstances.size());
		
		// generate verifier
		Checker v = null;
		if (check)
			v = new Checker(tracerInstances);
		
		// create Tracers Coding
		TracerProvider tp;

		if (tracerEqualPriority(tracer)) {
			// normal coding
			tp = new EqualCodingTracerProvider(br, tracerInstances);
		} else {
			tp = new VariableCodingTracerProvider(br, tracerInstances);
		}

		// Decompression-Phase

		if (cycleAccurate) {

			int cyclesNext = pot2(timeBits)-1;
			int cycles;

			BitVector[][] values = new BitVector[tracerInstances.size()][];			

			cycles = br.getBitsAsInt(timeBits);

			int allCycles = 0;
			
			while (true) {

				while (cycles == cyclesNext) {					
					allCycles += cycles-1;
					tw.nextCycle(cycles - 1);
					if (check)
						v.doEmptyCycles(cycles-1);
					
					cycles = br.getBitsAsInt(timeBits);
				}

				allCycles += cycles;
				tw.nextCycle(cycles);
				if(check)
					v.doEmptyCycles(cycles-1);

				allCycles = 0;
				
				// have a valid cycle

				for (int i = 0; i < values.length; i++) {
					values[i] = tracerInstances.get(i).getNextEmptyMessage();
				}
				
				int lastTracerInstIndex = Integer.MAX_VALUE;
				
				do {
					
					TracerInstance curTracerInst = tp.getNextTracerInstance();
											
					int tracerInstIndex = tracerInstances.indexOf(curTracerInst);
					
					// posttrigger
					if(tracerInstIndex == lastTracerInstIndex){
						tw.write(values);
						for (int i = 0; i < values.length; i++) {
							values[i] = tracerInstances.get(i).getNextEmptyMessage();
						}
					}
					lastTracerInstIndex = tracerInstIndex;
					
					values[tracerInstIndex] = curTracerInst
							.getNextFullMessage();

					// check if first bit of last tracer is set (finish trace)					
					if(values[values.length-1][0]!=null){// system-tracer send message
						if (values[values.length-1][0].get(0)){
							tw.write(values);
							tw.close();
							return;	
						}						
					}
						
					// get next cycle
					cycles = br.getBitsAsInt(timeBits);

				} while (cycles == 0);
				
				tw.write(values);				
				
				if(check)
					v.doCycle(values);
				
			}

		} else { // non cycle-accurate tracing

			BitVector[][] values = new BitVector[tracerInstances.size()][];

			while (true) {

				for (int i = 0; i < values.length; i++) {
					values[i] = tracerInstances.get(i).getNextEmptyMessage();
				}

				TracerInstance curTracerInst = tp.getNextTracerInstance();

				values[tracerInstances.indexOf(curTracerInst)] = curTracerInst
						.getNextFullMessage();

				tw.nextCycle(1);
				tw.write(values);
				
				// check if first bit of last tracer is set (finish trace)					
				if(values[values.length-1][0]!=null){// system-tracer send message
					if (values[values.length-1][0].get(0)){
						tw.close();
						return;	
					}						
				}

			}

		}
		

	}

	/**
	 * Return <code>true</code>, if all tracer have the same priority.
	 * 
	 * @param tr
	 * @return
	 */
	private static boolean tracerEqualPriority(List<Tracer> tr) {
		if (tr.isEmpty())
			return true;
		int priority = tr.get(0).getPriority();
		for (int i = 1; i < tr.size(); i++)
			if (tr.get(i).getPriority() != priority)
				return false;

		return true;

	}
	
	private static int pot2(int exponent) {
		if ((exponent < 0) | (exponent > 31))
			return -1;

		int result = 1;
		for (int i = 0; i < exponent; i++) {
			result = result * 2;
		}
		return result;
	}

}
