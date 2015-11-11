package ite.trace.processing.traceConfig;

import ite.trace.types.CompressionType;

/**
 * A representation for ports.
 * 
 * @author Stefan Alex
 */

public class Port {

	private final short id;

	private final short width;

	private final short inputs;

	private final CompressionType comp;

	/**
	 * 
	 * @return the id of the port.
	 */
	public short getId() {
		return id;
	}

	/**
	 * 
	 * @return the width of the port.
	 */
	public short getWidth() {
		return width;
	}

	/**
	 * 
	 * @return the inputs of the port.
	 */
	public short getInputs() {
		return inputs;
	}

	/**
	 * 
	 * @return the compression-type of the port.
	 */
	public CompressionType getComp() {
		return comp;
	}

	/**
	 * The Constructor.
	 * 
	 * @param id
	 * @param width
	 * @param inputs
	 * @param comp
	 */
	protected Port(short id, short width, short inputs, CompressionType comp) {
		super();
		this.id = id;
		this.width = width;
		this.inputs = inputs;
		if (width < 8)
			this.comp = CompressionType.noneC;
		else
			this.comp = comp;
	}

	/**
	 * 
	 * @param p
	 *            a port
	 * @return <code>true</code>, if <code>p</code> equals this one.
	 */
	protected boolean equals(Port p) {
		return id == p.id;
	}

}
