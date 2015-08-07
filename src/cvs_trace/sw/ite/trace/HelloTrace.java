package ite.trace;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.Iterator;

import ite.trace.processing.TraceController;
import ite.trace.types.TriggerMode;
import ite.trace.types.TriggerOneRegisterCompareType;
import ite.trace.types.TriggerTwoRegistersCompareType;
import ite.trace.types.TriggerType;
import ite.trace.util.BitVector;
import ite.trace.exceptions.InvalidBitRepresentationException;
import ite.trace.exceptions.InvalidConfigException;
import ite.trace.exceptions.InvalidLengthException;
import ite.trace.exceptions.InvalidMessageException;
import ite.trace.exceptions.InvalidTraceException;

public class HelloTrace {

	private static TraceController traceController;

	private static BufferedReader br;

	/**
	 * Main method.
	 * 
	 * @param args
	 */
	public static void main(String[] args) {

		br = new BufferedReader(new InputStreamReader(System.in));

		System.out.println("Trace-Control");
		System.out.println("=============");
		System.out.println("");

		try {
			traceController = new TraceController();

			while (true) {

				System.out.println("Menu");
				System.out.println("====");
				System.out.println("");
				System.out.println("1. Connect");
				System.out.println("2. Show Configuration");
				System.out.println("3. ICE-Functions");
				System.out.println("4. Set Trigger");
				System.out.println("5. Start Trace");
				System.out.println("6. Stop Trace");
				System.out.println("7. Decompress Tracefile");
				System.out.println("0. Exit");

				int input = readNumber(0, 7);
				if (input == 0) {
					traceController.close();
					System.exit(0);
				}
				if (input == 1)
					connect();
				if (input == 2)
					printConfig();
				if (input == 3)
					ice();
				if (input == 4)
					setTrigger();
				if (input == 5)
					startTracing();
				if (input == 6)
					stopTracing();
				if (input == 7)
					decompressTrace();

			}

		} catch (InvalidConfigException ice) {
			ice.printStackTrace(); // TODO
			switch (ice.getErrorCode()) {
			case -2: {
				System.out
						.println("ERROR: Configuration-Message contains invalid trigger-event-number.");
				System.exit(-1);
			}
			case -1: {
				System.out
						.println("ERROR: Configuration-Message contains invalid port-number.");
				System.exit(-1);
			}
			case 0: {
				System.out
						.println("ERROR: Configuration-Message has no complete port-information.");
				System.exit(-1);
			}
			case 1: {
				System.out
						.println("ERROR: Configuration-Message has no complete trigger-information.");
				System.exit(-1);
			}
			case 2: {
				System.out
						.println("ERROR: Configuration-Message has no complete instruction-tracer-information.");
				System.exit(-1);
			}
			case 3: {
				System.out
						.println("ERROR: Configuration-Message has no complete message-tracer-information.");
				System.exit(-1);
			}
			case 4: {
				System.out
						.println("ERROR: Configuration-Message has no complete memory-tracer-information.");
				System.exit(-1);
			}
			case 5: {
				System.out
						.println("ERROR: Configuration-Message has no complete statistic-zracer-information.");
				System.exit(-1);
			}
			case 6: {
				System.out
						.println("ERROR: Configuration-Message has no complete ICE-information.");
				System.exit(-1);
			}

			case 7: {
				System.out.println("ERROR: Configuration-Message is too long.");
				System.exit(-1);
			}
			case 8: {
				System.out
						.println("ERROR: Trace-Configuration has too many trigger-inputs.");
				System.exit(-1);
			}
			case 9: {
				System.out
						.println("ERROR: Trace-Configuration has too many trigger-events.");
				System.exit(-1);
			}
			case 10: {
				System.out
						.println("ERROR: Trace-Configuration has too many trigger.");
				System.exit(-1);
			}
			case 11: {
				System.out
						.println("ERROR: Configuration-Message has no complete additional information.");
				System.exit(-1);
			}
			case 12: {
				System.out
						.println("ERROR: Configuration-Message contains no system-message-tracer.");
				System.exit(-1);
			}
			}
		} catch (InvalidMessageException ime) {
			System.out.println("ERROR: A received message is invalid.");
			System.exit(-1);
		} catch (InvalidTraceException ite) {
			switch (ite.getErrorCode()) {

			case 0: {
				System.out.println("ERROR: Trace contains a wrong coding.");
				ite.printStackTrace();
				System.exit(-1);
			}
			case 1: {
				System.out.println("ERROR: Trace contains incomplete data.");
				System.exit(-1);
			}
			case 2: {
				System.out.println("ERROR: Trace contains invalid LS-Encoding.");
				System.exit(-1);
			}
			}
		} catch (IOException ioe) {
			ioe.printStackTrace();
			System.out.println("ERROR: An IO-Exception occured.");
			System.exit(-1);
		} catch (InvalidLengthException ile) {
			ile.printStackTrace();
			System.out.println("ERROR: An internal error occured.");
		}

	}

	/**
	 * Connect controller to fpga-board.
	 * 
	 * @throws InvalidConfigException when the configuration is invalid.
	 * @throws InvalidMessageException when the transmitted configuration-message is invalid.
	 * @throws IOException when an io-error occures.
	 */
	private static void connect() throws InvalidConfigException,
			InvalidMessageException, IOException {
		traceController.connect();
		System.out.println("Connected.");
		System.out.println("");
	}

	/**
	 * Prints the current system-configuration and register-values
	 * 
	 */
	private static void printConfig(){

		if (!traceController.connected()) {
			System.out.println("ERROR: Please connect to fpga-board.");
			System.out.println("");
			return;
		}

		while (true) {

			System.out.println("Trace-Configuration");
			System.out.println("===================");
			System.out.println("");
			System.out.println("1. Ports");
			System.out.println("2. Tracer");
			System.out.println("3. Trigger");
			System.out.println("4. Additional Information");
			System.out.println("0. Back");

			int input = readNumber(0, 4);
			if (input == 0)
				return;

			if (input == 1) { // show ports

				if (traceController.getPortCnt() == 0) {
					System.out.println("No ports specified.");
				} else {

					Iterator<Integer> portIds = traceController.getPortIds();

					System.out.println("|---|-----|------|----|");
					System.out.println("|Id.|Width|Inputs|Comp|");
					System.out.println("|---|-----|------|----|");

					while (portIds.hasNext()) {
						int id = portIds.next();
						System.out.println("|"
								+ generateDigits(3, id)
								+ "|"
								+ generateDigits(5, traceController
										.getPortWidth(id))
								+ "|"
								+ generateDigits(6, traceController
										.getPortInputs(id))
								+ "|"
								+ generateDigits(4, traceController
										.getPortComp(id).toString()) + "|");
					}
					System.out.println("|---|-----|------|----|");
					System.out.println("");

				}
			}

			if (input == 2) { // show tracer

				if (traceController.getInstTracerCnt() == 0) {
					System.out.println("No Instruction-Tracer specified.");
					System.out.println("");
				} else {

					System.out.println("Instruction-Tracer");
					System.out.println("");

					System.out
							.println("|---|---------|--------|-----------|------|-----------|-------|------------|-------------|");
					System.out
							.println("|Id.|Instances|Priority|Adress-Port|Branch|Branch-Port|History|History-Bits|Counter-Bytes|");
					System.out
							.println("|---|---------|--------|-----------|------|-----------|-------|------------|-------------|");

					for (int i = 0; i < traceController.getInstTracerCnt(); i++) {

						System.out
								.println("|"
										+ generateDigits(3, i)
										+ "|"
										+ generateDigits(9, traceController
												.getInstTracerInstances(i))
										+ "|"
										+ generateDigits(8, traceController
												.getInstTracerPriority(i))
										+ "|"
										+ generateDigits(11, traceController
												.getInstTracerAdrPort(i))
										+ "|"
										+ (traceController
												.getInstTracerIsBranchInfo(i) ? "  True"
												: " False")
										+ "|"
										+ generateDigits(11, traceController
												.getInstTracerBranchPort(i))
										+ "|"
										+ (traceController
												.getInstTracerIsHistory(i) ? "   True"
												: "  False")
										+ "|"
										+ generateDigits(12, traceController
												.getInstTracerHistoryBytes(i))
										+ "|"
										+ generateDigits(13, traceController
												.getInstTracerCounterBits(i))
										+ "|");
					}

					System.out
							.println("|---|---------|--------|-----------|------|-----------|-------|------------|-------------|");
					System.out.println("");
				}

				if (traceController.getMemTracerCnt() == 0) {
					System.out.println("No Memory-Tracer specified.");
					System.out.println("");
				} else {

					System.out.println("Memory-Tracer");
					System.out.println("");
					System.out
							.println("|---|---------|--------------|--------|-----------|---------|-------|-----------|");
					System.out
							.println("|Id.|Instances|Collect Values|Priority|Adress-Port|Data-Port|Rw-Port|Source-Port|");
					System.out
							.println("|---|---------|--------------|--------|-----------|---------|-------|-----------|");

					for (int i = 0; i < traceController.getMemTracerCnt(); i++) {

						Iterator<Integer> portIt = traceController
								.getMemTracerAdrPorts(i);

						String line = "|"
								+ generateDigits(3, i)
								+ "|"
								+ generateDigits(9, traceController
										.getMemTracerInstances(i))
								+ "|"
								+ (traceController.getMemTracerCollectVal(i) ? fillString(
										"True", 14)
										: fillString("False", 14))
								+ "|"
								+ generateDigits(8, traceController
										.getMemTracerPriority(i)) + "|";

						boolean firstline = true;

						while (portIt.hasNext()) {

							int id = portIt.next();

							line = line + generateDigits(11, id) + "|";

							if (firstline) {
								line = line
										+ generateDigits(9, traceController
												.getMemTracerDataPort(i))
										+ "|"
										+ generateDigits(7, traceController
												.getMemTracerRwPort(i))
										+ "|"
										+ generateDigits(11, traceController
												.getMemTracerSourcePort(i))
										+ "|";

								firstline = false;
							} else {

								line = line + generateDigits(9, "") + "|"
										+ generateDigits(7, "") + "|"
										+ generateDigits(11, "") + "|";

							}

							System.out.println(line);

							line = "|" + generateDigits(3, "") + "|"
									+ generateDigits(9, "") + "|"
									+ generateDigits(14, "") + "|"
									+ generateDigits(8, "") + "|";
						}

					}
					System.out
							.println("|---|---------|--------------|--------|-----------|---------|-------|-----------|");
					System.out.println("");
				}

				if (traceController.getMessageTracerCnt() == 0) {
					System.out.println("No Message-Tracer specified.");
					System.out.println("");
				} else {

					System.out.println("Message-Tracer");
					System.out.println("");
					System.out.println("|---|---------|--------|------------|");
					System.out.println("|Id.|Instances|Priority|Message-Port|");
					System.out.println("|---|---------|--------|------------|");

					for (int i = 0; i < traceController.getMessageTracerCnt(); i++) {

						Iterator<Integer> portIt = traceController
								.getMessageTracerMsgPorts(i);

						String line = "|"
								+ generateDigits(3, i)
								+ "|"
								+ generateDigits(9, traceController
										.getMessageTracerInstances(i))
								+ "|"
								+ generateDigits(8, traceController
										.getMessageTracerPriority(i)) + "|";

						while (portIt.hasNext()) {

							int id = portIt.next();

							line = line + generateDigits(12, id) + "|";

							System.out.println(line);

							line = "|" + generateDigits(3, "") + "|"
									+ generateDigits(9, "") + "|"
									+ generateDigits(8, "") + "|";

						}

					}
					System.out.println("|---|---------|--------|------------|");
					System.out.println("");
				}
			}

			if (input == 3) {

				if (traceController.getTriggerSingleEventCnt() == 0) {
					System.out.println("No single-events specified");
					System.out.println("");
				} else {

					System.out.println("Trigger-Single-Events");
					System.out.println("");

					int[] seIds = traceController.getTriggerSingleEventIds();
					
					int maxRegisterTextWidth = traceController
							.getMaxTriggerRegisterWidth();					
					maxRegisterTextWidth = Math.max(maxRegisterTextWidth, 10);
					
					int maxCompOpTextWidth = 0;
					for (int i = 0; i < seIds.length; i++) {
						if (traceController.getTriggerRegisterCompareType(seIds[i])
								.toString().length() > maxCompOpTextWidth)
							maxCompOpTextWidth = traceController.getTriggerRegisterCompareType(seIds[i]).toString().length();
					}
					maxCompOpTextWidth = Math.max(maxCompOpTextWidth, 7);

					System.out.println("|-------|--------|"
							+ manifoldDigit('-', maxRegisterTextWidth)+"|"
							+ manifoldDigit('-', maxCompOpTextWidth) + "|");
					System.out
							.println("|TSE-Id.|Port-Id.|"
									+ generateDigits(maxRegisterTextWidth,
											"Reg.-Value") + "|"
									+generateDigits(maxCompOpTextWidth, "Comp-Op.")+"|");
					System.out.println("|-------|--------|"
							+ manifoldDigit('-', maxRegisterTextWidth) + "|"
							+ manifoldDigit('-', maxCompOpTextWidth) + "|");

					for (int i = 0; i < seIds.length; i++) {

						int id = seIds[i];

						System.out.println("|"
								+ generateDigits(7, id)
								+ "|"
								+ generateDigits(8, traceController
										.getTriggerSingleEventPortId(id))
								+ "|"
								+ generateDigits(maxRegisterTextWidth,
										traceController
												.getTriggerRegisterValue(id,
														false)
												.getBinaryString())
								+ "|"
								+ generateDigits(maxCompOpTextWidth, traceController
										.getTriggerRegisterCompareType(id)
										.toString()) + "|");

						if (traceController
								.getTriggerEventHasSecondRegister(id)) {
							System.out.println("|"
									+ manifoldDigit(' ', 7)
									+ "|"
									+ manifoldDigit(' ', 8)
									+ "|"
									+ generateDigits(maxRegisterTextWidth,
											traceController
													.getTriggerRegisterValue(
															id, true)
													.getBinaryString()) + "|"
									+ generateDigits(maxCompOpTextWidth, "") + "|");
						}

					}

					System.out.println("|-------|--------|"
							+ manifoldDigit('-', maxRegisterTextWidth)+"|"
							+ manifoldDigit('-', maxCompOpTextWidth) + "|");
					System.out.println("");

					System.out.println("Trigger");
					System.out.println("");

					int trigIds[] = traceController.getTriggerIds();

					int maxModeTextWidth = 0;
					for (int i = 0; i < trigIds.length; i++) {
						if (traceController.getTriggerMode(trigIds[i])
								.toString().length() > maxModeTextWidth)
							maxModeTextWidth = traceController.getTriggerMode(
									trigIds[i]).toString().length();
					}
					maxModeTextWidth = Math.max(maxModeTextWidth, 4);

					int maxTypeTextWidth = 0;
					for (int i = 0; i < trigIds.length; i++) {
						if (traceController.getTriggerType(trigIds[i])
								.toString().length() > maxTypeTextWidth)
							maxTypeTextWidth = traceController.getTriggerType(
									trigIds[i]).toString().length();
					}
					maxTypeTextWidth = Math.max(maxTypeTextWidth, 4);

					int maxActivTextWidth = 0;
					for (int i = 0; i < trigIds.length; i++) {
						if (traceController.getTriggerEvents(trigIds[i]) > maxActivTextWidth)
							maxActivTextWidth = traceController
									.getTriggerEvents(trigIds[i]);
					}
					maxActivTextWidth = Math.max(maxActivTextWidth, 5);

					System.out.println("|---------|"
							+ manifoldDigit('-', maxModeTextWidth) + "|"
							+ manifoldDigit('-', maxTypeTextWidth) + "|"
							+ manifoldDigit('-', maxActivTextWidth) + "|");
					System.out.println("|Trig.-Id.|"
							+ generateDigits(maxModeTextWidth, "Mode") + "|"
							+ generateDigits(maxTypeTextWidth, "Type") + "|"
							+ generateDigits(maxActivTextWidth, "Activ") + "|");
					System.out.println("|---------|"
							+ manifoldDigit('-', maxModeTextWidth) + "|"
							+ manifoldDigit('-', maxTypeTextWidth) + "|"
							+ manifoldDigit('-', maxActivTextWidth) + "|");

					for (int i = 0; i < trigIds.length; i++) {

						String activ = "";
						for (int j = 0; j < traceController
								.getTriggerEvents(trigIds[i]); j++) {
							activ = activ
									+ (traceController.getTriggerActiv(
											trigIds[i], j) ? "A" : "I");
						}

						System.out.println("|"
								+ generateDigits(9, trigIds[i])
								+ "|"
								+ generateDigits(maxModeTextWidth,
										traceController.getTriggerMode(
												trigIds[i]).toString())
								+ "|"
								+ generateDigits(maxTypeTextWidth,
										traceController.getTriggerType(
												trigIds[i]).toString()) + "|"
								+ generateDigits(maxActivTextWidth, activ)
								+ "|");
					}

					System.out.println("|---------|"
							+ manifoldDigit('-', maxModeTextWidth) + "|"
							+ manifoldDigit('-', maxTypeTextWidth) + "|"
							+ manifoldDigit('-', maxActivTextWidth) + "|");
					System.out.println("");

				}
			}

			if (input == 4) {
				String line = "ICE-Register-Width: ";
				if (traceController.getIceRegisterCnt() == 0)
					line = line + "no registers specified";
				else {
					for (int i = 0; i < traceController.getIceRegisterCnt(); i++)
						line += traceController.getIceRegisterWidth(i) + " ";
				}
				System.out.println(line);
				System.out
						.println("Cycle-Accurate: "
								+ (traceController.isCycleAccurate() ? "True"
										: "False"));
				System.out
						.println("Trigger-Inform: "
								+ (traceController.isInformTrigger() ? "True"
										: "False"));
				System.out.println("");
			}
		}
	}

	/**
	 * Then user-interface for ice-functions.
	 * 
	 * @throws InvalidMessageException when an recevied message is invalid.
	 */
	private static void ice() throws IOException, InvalidMessageException {

		if (!traceController.connected()) {
			System.out.println("ERROR: Please connect to fpga-board.");
			System.out.println("");
			return;
		}

		while (true) {
			System.out.println("ICE-Functions");
			System.out.println("=============");
			System.out.println("");
			System.out.println("1. Pause System");
			System.out.println("2. Show Register");
			System.out.println("3. Set Register");
			System.out.println("4. Restart System");
			System.out.println("0. Back");

			int input = readNumber(0, 4);
			if (input == 0)
				break;
			if (input == 1) {
				if (traceController.iceStopSystem())
					System.out.println("System stopped.");
				else
					System.out
							.println("Could not stop system. And error occured.");
			}
			if (input == 2) {
				int regs = traceController.getIceRegisterCnt();
				if (regs == 0)
					System.out.println("There are no ice-registers.");
				else {
					BitVector values = traceController.getIceRegisterValues();
					int index = 0;
					int width;
					for (int i = 0; i < regs; i++) {
						width = traceController.getIceRegisterWidth(i);
						System.out.println("Register "
								+ i
								+ " with width "
								+ width
								+ " and value "
								+ values.getSubvector(index, index + width)
										.getHexString());
						index = index + width;
					}
				}
			}
			if (input == 3) {
				int regs = traceController.getIceRegisterCnt();
				if (regs == 0) {
					System.out.println("There are no ice-registers");
				} else {
					System.out.println("Please insert register-id (" + regs
							+ " possible)(-1 = back)");
					int id = readNumber(-1, regs - 1);
					if (id != -1) {
						int width = traceController.getIceRegisterWidth(id);
						System.out
								.println("Please insert "
										+ width
										+ "-Bit value (value is trimmed or filled with zeros)(-1 = back)");
						BitVector bv = readBinaryValue(width);
						if (bv == null)
							break;

						if (traceController.setIceRegisterValue(id, bv))
							System.out.println("Register updated.");
						else
							System.out.println("Could not update register.");
					}
				}
			}
			if (input == 4) {
				if (traceController.iceStartSystem())
					System.out.println("System restarted");
				else
					System.out.println("Could not restart System.");

			}
			System.out.println("");
		}
	}

	/**
	 * Set new values to the trigger-registers and set control-values
	 * 
	 * @throws InvalidMessageException
	 * @throws InvalidConfigException
	 * @throws IOException
	 */
	private static void setTrigger() throws InvalidMessageException,
			InvalidConfigException, IOException {

		if (!traceController.connected()) {
			System.out.println("ERROR: Please connect to fpga-board.");
			System.out.println("");
			return;
		}

		int triggerInputCnt = traceController.getTriggerCnt();

		if (triggerInputCnt == 0) {
			System.out
					.println("There are no trigger in the current system-configuration.");
			System.out.println("");
			return;
		}

		while (true) {
			System.out.println("Set Trigger");
			System.out.println("===========");
			System.out.println("");
			System.out.println("1. Set Trigger-Register");
			System.out.println("2. Set Trigger-Register Compare-Type");
			System.out.println("3. Turn Trigger-Event On/Off");
			System.out.println("4. Set Mode");
			System.out.println("5. Set Type");
			System.out.println("0. Back");

			int input = readNumber(0, 5);

			if (input == 0)
				break;

			if (input == 1) {

				System.out
						.println("Please insert the single-event-id (0 = back)");
				int id = readNumber(traceController.getTriggerSingleEventIds(),
						0);

				if (id == 0)
					break;

				System.out
						.println("Please insert "
								+ traceController.getTriggerRegisterWidth(id)
								+ "-Bit for first register (value filled with zeros)(-1 = back)");
				BitVector bv = readBinaryValue(traceController
						.getTriggerRegisterWidth(id));
				if (bv == null)
					break;

				if (traceController.setTriggerRegisterValue(id, false, bv))
					System.out.println("Register updated.");
				else
					System.out.println("Could not update register.");

				if (traceController.getTriggerEventHasSecondRegister(id)) {
					System.out
							.println("Please insert "
									+ traceController
											.getTriggerRegisterWidth(id)
									+ "-Bit for second register(value is filled with zeros)(-1 = back)"
									+ "");

					bv = readBinaryValue(traceController
							.getTriggerRegisterWidth(id));
					if (bv == null)
						break;

					if (traceController.setTriggerRegisterValue(id, true, bv))
						System.out.println("Register updated.");
					else
						System.out.println("Could not update register.");

				}

			}

			if (input == 2) {

				System.out
						.println("Please insert the single-event-id (0 = back)");

				int id = readNumber(traceController.getTriggerSingleEventIds(),
						0);

				if (id == 0)
					break;

				boolean hasSecondRegister = traceController
						.getTriggerEventHasSecondRegister(id);

				if (!hasSecondRegister) {
					for (int i = 0; i < TriggerOneRegisterCompareType.values().length; i++) {
						System.out.println((i + 1)
								+ ". "
								+ TriggerOneRegisterCompareType.get(i)
										.toString());						
					}
					System.out.println("0. Back");
					
					int sel = readNumber(0, TriggerMode.values().length);

					if (sel == 0)
						break;

					if (traceController.setTriggerRegisterCompareType(id,
							TriggerOneRegisterCompareType.get(sel - 1)))
						System.out.println("Compare-Type updated.");
					else
						System.out.println("Could not update compare-type.");
				} else {
					for (int i = 0; i < TriggerTwoRegistersCompareType.values().length; i++) {
						System.out.println((i + 1)
								+ ". "
								+ TriggerTwoRegistersCompareType.get(i)
										.toString());						
					}
					System.out.println("0. Back");
					int sel = readNumber(0, TriggerMode.values().length);

					if (sel == 0)
						break;

					if (traceController.setTriggerRegisterCompareType(id,
							TriggerTwoRegistersCompareType.get(sel - 1)))
						System.out.println("Compare-Type updated.");
					else
						System.out.println("Could not update compare-type.");
				}

			}

			if (input == 3) {

				System.out.println("Please insert trigger-id (0 = back)");

				int id = readNumber(traceController.getTriggerIds(), 0);

				if (id == 0)
					break;

				System.out.println("Please insert event-number (0 = back)");
				int eventNo = readNumber(0, traceController
						.getTriggerEvents(id));

				if (eventNo == 0)
					break;

				eventNo--;
				
				if (!traceController.containsTrigger(id)) {
					System.out.println("Invalid id.");
					break;
				}

				boolean oldValue = traceController.getTriggerActiv(id, eventNo);

				if (traceController.setTriggerActiv(id, eventNo))
					if (oldValue == false)
						System.out.println("Trigger turned on.");
					else
						System.out.println("Trigger turned off.");
				else
					System.out.println("Could not update trigger.");

			}
			if (input == 4) {

				System.out.println("Please insert trigger-id (0 = back)");

				int id = readNumber(traceController.getTriggerIds(), 0);

				if (id == 0)
					break;

				for (int i = 0; i < TriggerMode.values().length; i++) {
					System.out.println((i + 1) + ". "
							+ TriggerMode.get(i).toString());					
				}
				System.out.println("0. Back");
				int sel = readNumber(-1, TriggerMode.values().length);

				if (sel == 0)
					break;

				if (traceController
						.setTriggerMode(id, TriggerMode.get(sel - 1)))
					System.out.println("Mode updated.");
				else
					System.out.println("Could not update mode.");
			}
			if (input == 5) {
				System.out.println("Please insert trigger-id (0 = back)");

				int id = readNumber(traceController.getTriggerIds(), 0);

				if (id == 0)
					break;

				for (int i = 0; i < TriggerType.values().length; i++) {
					System.out.println((i + 1) + ". "
							+ TriggerType.get(i).toString());					
				}
				System.out.println("0. Back");
				int sel = readNumber(0, TriggerMode.values().length);

				if (sel == 0)
					break;

				if (traceController
						.setTriggerType(id, TriggerType.get(sel - 1)))
					System.out.println("Type updated.");
				else
					System.out.println("Could not update type.");
			}

		}
		System.out.println("");
	}

	/**
	 * Start capturing trace.
	 * 
	 * @throws InvalidMessageException
	 */
	private static void startTracing() throws InvalidMessageException {

		if (!traceController.connected()) {
			System.out.println("ERROR: Please connect to fpga-board.");
			System.out.println("");
			return;
		}

		System.out.println("Please insert a filename (-1 = back)");
		try {
			String input = br.readLine();
			if (input.equals("-1"))
				return;
			if (br.equals(""))
				System.out.println("Invalid filename");
			else {
				File f = getNewFile(input);
				System.out.println("File " + f.getName() + " created.");
				if (traceController.startTracing(f))
					System.out.println("Trace started.");
				else
					System.out.println("ERROR: Could not start trace.");
			}
		} catch (IOException ioe) {
			System.out.println("ERROR: Could not read input.");
		}

		System.out.println("");

	}

	/**
	 * Stop capturing trace.
	 * 
	 * @throws InvalidMessageException
	 * @throws IOException
	 */
	private static void stopTracing() throws InvalidMessageException,
			IOException {

		if (!traceController.connected()) {
			System.out.println("ERROR: Please connect to fpga-board.");
			System.out.println("");
			return;
		}

		if (traceController.stopTracing())
			System.out.println("Trace stopped.");
		else
			System.out.println("ERROR: Could not stop trace.");

		System.out.println("");

	}

	/**
	 * Decompress trace.
	 */
	private static void decompressTrace() throws InvalidConfigException,
			InvalidTraceException, InvalidLengthException {

		System.out.println("Please insert a filename (-1 = back)");

		while (true) {
			try {

				String input = br.readLine();

				if (input.equals("-1")) {
					break;
				} else {
					File f = new File(input);
					traceController.decompressTrace(f);
					System.out.println("Trace decompressed.");
					break;
				}

			} catch (FileNotFoundException fnfe) {
				System.out.println("ERROR: Could not find trace-file.");
			} catch (IOException ioe) {
				System.out.println("ERROR: Could not read input.");
			}
		}

		System.out.println("");

	}

	/**
	 * Generates a new file. If the filename exists, it appends an index.
	 * 
	 * @param filename
	 * @return
	 * @throws IOException
	 */
	private static File getNewFile(String filename) throws IOException {
		File f = new File(filename);
		while (!f.createNewFile())
			f = new File(incfilename(f.getName()));

		return f;
	}

	/**
	 * Creates an index for the filename.
	 * 
	 * @param filename
	 * @return
	 */
	private static String incfilename(String filename) {
		char lastsymbol = filename.charAt(filename.length() - 1);

		String newfilename = "";

		if (('0' <= lastsymbol) && (lastsymbol <= '9')) {

			if (lastsymbol == '9') {
				newfilename = incfilename(filename.substring(0, filename
						.length() - 1));
				newfilename += '0';
			} else {

				newfilename = filename.substring(0, filename.length() - 1)
						+ (char) (lastsymbol + 1);
			}
		} else {
			newfilename = filename + "1";
		}

		return newfilename;
	}

	/**
	 * Returns a string, which contains the Character <code>c</code>
	 * <code>cnt</code> times.
	 * 
	 * @param c
	 * @param cnt
	 * @return
	 */
	private static String manifoldDigit(char c, int cnt) {
		String result = "";
		for (int i = 0; i < cnt; i++) {
			result = result + c;
		}
		return result;
	}

	/**
	 * Reads a binary value. The value is filled with zeros, if it not matches
	 * the length. If the string has 0x as first digits, it it is interpreted as
	 * hexadecimal value. If <code>-1<code> is inserted, <code>null</code> is
	 * returned.
	 * 
	 * @param length
	 *            the length
	 * @return a <code>BitVector</code>-Object
	 */
	private static BitVector readBinaryValue(int length) {

		String input;

		while (true) {
			try {
				input = br.readLine();

				if (input.equals("-1"))
					return null;

				if (input.length() >= 2 && input.substring(0, 2).equals("0x"))
					return new BitVector(length, input.substring(2));
				else {
					BitVector bv = new BitVector(length);
					bv.setBinaryString(input);
					return bv;
				}

			} catch (IOException ioe) {
				System.out.println("ERROR: Could not read input.");
			} catch (InvalidLengthException ile) {
				System.out
						.println("ERROR: The Input don't matches the registers length.");
			} catch (InvalidBitRepresentationException ibre) {
				System.out.println("ERROR: The Input has an invalid format.");
			}
		}

	}

	/**
	 * Read a number between <code>min</code> and <code>max</code>.
	 * 
	 * @param min
	 * @param max
	 * @return
	 */
	private static int readNumber(int min, int max) {
		String input;

		while (true) {
			try {
				input = br.readLine();

				int number = Integer.parseInt(input);

				if ((number >= min) && (number <= max)) {
					return number;
				} else {
					System.out.println("Value must be between " + min + " and "
							+ max);
				}

			} catch (IOException ioe) {
				System.out.println("ERROR: Could not read input.");
			} catch (NumberFormatException nfe) {
				System.out.println("ERROR: Invalid input.");
			}
		}
	}

	/**
	 * Read a number contained in values or add.
	 */
	private static int readNumber(int[] values, int add) {
		String input;

		while (true) {
			try {
				input = br.readLine();

				int number = Integer.parseInt(input);

				for (int i : values) {
					if (i == number)
						return number;
				}
				if (number == add)
					return number;

				System.out.println("Invalid input.");

			} catch (IOException ioe) {
				System.out.println("ERROR: Could not read input.");
			} catch (NumberFormatException nfe) {
				System.out.println("ERROR: Invalid input.");
			}
		}
	}

	/**
	 * Fill or cut a String to a given length
	 * 
	 * @param num
	 *            length
	 * @param value
	 *            String
	 * @return result
	 */
	private static String generateDigits(int num, String value) {
		if (value.length() == num)
			return value;

		if (value.length() < num) { // mit Leerzeichen auffüllen
			String e = "";
			for (int i = 0; i < num - value.length(); i++)
				e = e + " ";
			return e + value;
		} else { // kürzen

			return value.substring(0, num - 2) + "..";
		}
	}

	/**
	 * Fill or cut an int to a given length
	 * 
	 * @param num
	 *            length
	 * @param value
	 *            int
	 * @return result
	 */
	private static String generateDigits(int num, int value) {
		String s = Integer.toString(value);

		if (s.length() == num)
			return s;

		if (s.length() < num) { // mit Leerzeichen auffüllen
			String e = "";
			for (int i = 0; i < num - s.length(); i++)
				e = e + " ";
			return e + s;
		} else { // kürzen

			return s.substring(0, num - 2) + "..";
		}
	}

	/**
	 * If the string is shorter than <code>length</code>, it is filled with
	 * blanks.
	 * 
	 * @param string
	 * @param length
	 * @return
	 */
	private static String fillString(String string, int length) {

		String fill = "";

		for (int i = 0; i < length - string.length(); i++) {
			fill = fill + " ";
		}

		return fill + string;

	}

}
