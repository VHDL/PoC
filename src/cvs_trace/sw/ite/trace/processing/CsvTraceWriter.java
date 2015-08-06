package ite.trace.processing;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

import ite.trace.util.BitVector;

/**
 * Formats and writes trace-infomation to a file in the csv-format.
 * 
 * @author Stefan Alex
 * 
 */
public class CsvTraceWriter implements TraceWriter {

	private final FileWriter fr;
	private final int tracer;
	private long currentCycle;
	private int counter;

	/**
	 * The constructor.
	 * 
	 * @param destFile
	 *            the destination-file
	 * @param tracer
	 *            the number of tracers in the system
	 * @throws IOException
	 */
	public CsvTraceWriter(File destFile, int tracer) throws IOException {
		this.fr = new FileWriter(destFile);
		this.tracer = tracer;
		currentCycle = 0;
	}

	/**
	 * Finishs writing and close the csv-file.
	 * 
	 * @throws IOException
	 */
	public void close() throws IOException {
		fr.flush();
		fr.close();
	}

	/**
	 * Go to i cycles after the current one.
	 * 
	 * @param i
	 */
	public void nextCycle(int i) {
		if (i > 0)
			currentCycle += i;		
	}

	/**
	 * Writes trace-information of one cycle.
	 * 
	 * @param values
	 *            the values per tracer of this cycle.
	 * @throws IllegalArgumentException
	 *             when the number of value-array doesn't match the number of
	 *             tracer.
	 * @throws IOException
	 */
	public void write(BitVector[][] values) throws IllegalArgumentException,
			IOException {
		if (values.length != tracer)
			throw new IllegalArgumentException();

		fr.write(currentCycle + ",");
		for (BitVector[] v : values)
			for (BitVector bv : v)
				if (bv != null)
					fr.write(bv.getHexString() + ",");
				else
					fr.write(",");
		fr.write("\n");
		
		counter++;
		if (counter % 1000 == 1)
			fr.flush();
		fr.flush();
	}

}
