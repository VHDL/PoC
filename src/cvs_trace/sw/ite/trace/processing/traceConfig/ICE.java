package ite.trace.processing.traceConfig;

import java.util.List;

/**
 * In-Circuit-Emulator.
 * 
 * @author Stefan Alex
 * 
 */
public class ICE {

	private final short[] iceRegister;

	private final List<Trigger> trigger;

	/**
	 * 
	 * @return a list of then associated trigger.
	 */
	public List<Trigger> getTrigger() {
		return trigger;
	}

	/**
	 * The Constructor.
	 * 
	 * @param iceRegister
	 *            a list of the ice-register with there lengths
	 * @param trigger
	 *            the associated trigger
	 */
	protected ICE(final short[] iceRegister, final List<Trigger> trigger) {
		super();
		this.iceRegister = iceRegister;
		this.trigger = trigger;

	}

	/**
	 * 
	 * @return the number of configured ice-register.
	 */
	protected int getIceRegisterCnt() {
		return iceRegister.length;
	}

	/**
	 * @param i
	 *            the register-id
	 * @return the width of a given ice-register. If the register doesn't
	 *         exists, <code>-1</code> is returned.
	 */
	protected int getIceRegisterWidth(int i) {
		if (iceRegister.length < (i + 1))
			return -1;
		return iceRegister[i];

	}

	/**
	 * @return the maximal width of an ice-register.
	 */
	public int getIceRegisterMaxWidth() {
		int max = 0;
		for (int i = 0; i < iceRegister.length; i++) {
			if (iceRegister[i] > max)
				max = iceRegister[i];
		}
		return max;
	}

	/**
	 * @return the width of all ice-register as sum.
	 */
	public int getIceRegisterSumWidth() {
		int sum = 0;
		for (int i = 0; i < iceRegister.length; i++) {
			sum = sum + iceRegister[i];
		}
		return sum;
	}

}
