export interface PayslipInput {
  workerName: string;
  grossSalary: number;
  ssWorkerDeduction: number;
  irpfRate: number;
  irpfWithheld: number;
  netSalary: number;
}

export interface PayslipAuditResult {
  isValid: boolean;
  expectedNetSalary: number;
  expectedSsDeduction: number;
  netDiscrepancy: number;
  alerts: string[];
}

export class PayslipService {
  /**
   * Auditoría de nómina española conforme a cotizaciones 2026
   */
  auditPayslip(input: PayslipInput): PayslipAuditResult {
    const alerts: string[] = [];
    const gross = input.grossSalary;

    // Cotización estándar trabajador en España:
    // Contingencias Comunes: 4.70%
    // Desempleo (Indefinido): 1.55%
    // Formación Profesional: 0.10%
    // MEI (Mecanismo de Equidad Intergeneracional 2026): 0.12%
    // Total cotización SS aproximada trabajador: ~6.47%
    const expectedSsPercentage = 0.0647;
    const expectedSsDeduction = Math.round(gross * expectedSsPercentage * 100) / 100;

    const ssDiscrepancy = Math.abs(input.ssWorkerDeduction - expectedSsDeduction);
    if (ssDiscrepancy > 15.00) {
      alerts.push(
        `Desviación en deducción de Seguridad Social detectada (${input.ssWorkerDeduction} € declarados vs ~${expectedSsDeduction} € calculados al 6.47%). Verifica si existen horas extraordinarias o bases especiales.`
      );
    }

    // Comprobación de tipo de IRPF según volumen anual estimado (gross * 12 o 14)
    if (input.irpfRate < 2.0 && gross > 1200) {
      alerts.push(
        'Tipo de IRPF inferior al 2% en un salario superior al SMI. Riesgo de regularización con impacto negativo en la declaración de la Renta del trabajador.'
      );
    }

    // Comprobación de cuadre: Salario Neto = Salario Bruto - Deducción SS - Retención IRPF
    const expectedNetSalary = Math.round((gross - input.ssWorkerDeduction - input.irpfWithheld) * 100) / 100;
    const netDiscrepancy = Math.abs(input.netSalary - expectedNetSalary);

    if (netDiscrepancy > 0.05) {
      alerts.push(
        `Descuadre en el líquido a percibir: Bruto (${gross} €) - SS (${input.ssWorkerDeduction} €) - IRPF (${input.irpfWithheld} €) debería ser ${expectedNetSalary} €, pero la nómina indica ${input.netSalary} €.`
      );
    }

    return {
      isValid: alerts.length === 0,
      expectedNetSalary,
      expectedSsDeduction,
      netDiscrepancy,
      alerts
    };
  }
}

export const payslipService = new PayslipService();

