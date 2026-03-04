class PdfContentModel {
  // Page 1
  String dearName;
  String intro;
  String positionTitle;
  String positionBody;
  String compensationTitle;
  String compensationBody;
  String confidentialityTitle;
  String confidentialityBody;

  // Page 2
  String workingHoursTitle;
  String workingHoursBody;
  String leaveEligibilityTitle;
  String leaveEligibilityBody;
  String leaveAccrual;
  String publicHolidays;
  String specialLeave;
  String addOnsForMen;
  String addOnsForWomen;
  String leaveRequests;
  String leaveResponsibly;
  String leaveNote;
  String noticePeriodTitle;
  String noticePeriodBody;

  // Page 3
  String professionalConductTitle;
  String professionalConductBody1;
  String professionalConductBody2;
  String terminationAndRecoveryTitle;
  String terminationPoint1;
  String terminationPoint2;
  String terminationPoint3;
  String terminationPoint4;
  // Newly added termination points (5,6,7)
  String terminationPoint5;
  String terminationPoint6;
  String terminationPoint7;

  // Page 4
  // Moved Pre Employment Screening from Page 3 to Page 4
  String preEmploymentScreeningTitle;
  String preEmploymentScreeningBody;

  String disputeTitle;
  String disputeBody;
  String declarationTitle;
  String declarationBody;
  String acceptanceConfirmation;

  PdfContentModel({
    // Page 1
    this.dearName = "Dear {fullName},",
    this.intro =
        "      Thank You for your Interest in ZeAI Soft. Following our recent discussion, we are pleased to extend an offer for you to join ZeAI Soft. We are confident that your skills and experience will significantly contribute to our growth and success, and we look forward to welcoming you to the ZeAI Soft team!",
    this.positionTitle = "Position",
    this.positionBody =
        "      We are pleased to offer you the position of {position} at ZeAI Soft, starting on {doj}. In this role, you will report directly to the Team Lead (TL), who will provide guidance and support. You will be responsible for contributing to our operational initiatives during your training period. This role offers hands-on experience in software development, coding, debugging, and testing. You will also assist with live projects under the supervision of senior team members. Additionally, you will gain exposure to various technologies, tools, and processes. Your performance will be reviewed regularly throughout the training period. At the end of the program, you will be evaluated for a suitable permanent position. Compensation after training will be based on your performance.",
    this.compensationTitle = "Compensation",
    // <-- replaced hardcoded "November 2025" with placeholder {salaryFrom}
    this.compensationBody =
        "       You will be undergoing an internship with  ZeAI Soft for a period of 6 months and your monthly stipend will be  {stipend}. You will receive your salary payment from  {salaryFrom}. After successful completion of your training period, your salary will be revised to {ctc} based on your performance.",
    this.confidentialityTitle = "Confidentiality and Non Disclosure",
    this.confidentialityBody =
        "      You are expected to uphold the highest standards of confidentiality concerning the company's operations. This includes safeguarding all information, documents, instruments, and any materials related to the company that you encounter during your assessment period. Additionally, you must refrain from disclosing any confidential information in accordance with the \"Non-Disclosure and Confidentiality Policy.\"",

    // Page 2
    this.workingHoursTitle = "Working Hours",
    this.workingHoursBody =
        "      You are expected to maintain standard working hours of 9 AM to 6 PM, Monday to Friday designated as Work from Home, as discussed during the interview. Depending on project requirements, you may also be required to work shifts. The company reserves the right to modify shift timings at its discretion, with prior notice provided to you.",
    this.leaveEligibilityTitle = "Leave Eligibility",
    this.leaveEligibilityBody =
        "      As an employee of ZeAI Soft, you are entitled to a total of 24 leaves per year, which includes both casual and sick leave. The following outlines your leave eligibility:",
    this.leaveAccrual =
        "1. Leave Accrual: You will accrue 2 days of leave per month, summing up to 24 days annually.",
    this.publicHolidays =
        "2. Public Holidays: You are entitled to paid time off on all official public holidays recognized by the company.",
    this.specialLeave =
        "3. Special Leave: Additional leave may be granted for specific circumstances, such as bereavement, maternity/paternity leave, or jury duty, in accordance with company policy.",
    this.addOnsForMen =
        "4. Add Ons For Men: In addition to the 2 leaves available each month, men are entitled to take 1 additional leave for mental health reasons, if needed. That leave will be considered as \"Depressed/Sad Leave.\"",
    this.addOnsForWomen =
        "5. Add Ons For Women: In addition to the 2 leaves available each month, women are entitled to take 1 additional leave for their menstruation period followed by one day of WFH (Work From Home) if needed.",
    this.leaveRequests =
        "6. Leave Requests: Please ensure that you request leave in advance, subject to approval from your reporting person.",
    this.leaveResponsibly =
        "We encourage you to manage your leave responsibly and communicate any requests in a timely manner.",
    this.leaveNote =
        "Note - Apart from this, any additional leaves taken will be marked as LOP.",
    this.noticePeriodTitle = "Notice Period",
    this.noticePeriodBody =
        "      The employee may terminate the contract of employment by giving 3 months written notice to the Company. The employee must serve the notice period fully/partially even after their agreement period or internship is completed if they are allocated in client projects. The waiver of notice period fully or partially during the internship/employment is at the Company’s sole discretion. However, Company will also be entitled to terminate the contract of employment without assigning any reasons thereof.",

    // Page 3
    this.professionalConductTitle = "Professional Conduct",
    this.professionalConductBody1 =
        "      At ZeAI Soft, we prioritize professionalism and ethical conduct. All employees are expected to uphold these standards when handling the company's finances, materials, documents, and assets. Any violation of the company's code, including the disclosure of trade secrets, will result in immediate termination, regardless of the circumstances. If found guilty of dishonesty or misappropriation, you may be liable for damages as assessed by the company. You are prohibited from sharing any confidential information gained during your employment with anyone outside the organization.",
    this.professionalConductBody2 =
        "This includes communication about your remuneration or employment terms, which should only be discussed with your immediate superior. Failure to adhere to these standards will lead to immediate termination and potential legal action.",
    this.terminationAndRecoveryTitle = "Termination and Recovery",
    this.terminationPoint1 =
        "The Company reserves the right to terminate this contract and the Employee's employment at any time.",
    this.terminationPoint2 =
        "Upon termination, the Employee must promptly return all company assets and property, including documents, files, memos, and any other materials in their possession or control.",
    this.terminationPoint3 =
        "Any electronic devices containing conversations or details that violate company policy will be subject to confiscation for legal proceedings.",
    this.terminationPoint4 =
        "The Employee agrees not to pursue any other employment while under this contract and commits to obtaining prior consent from the Company before accepting any outside employment.",
    // New points added after the 4th point as requested
    this.terminationPoint5 =
        "In the event the Employee resigns or discontinues employment during the training/internship period, the Employee shall be liable to reimburse the Company for the cost of training, which includes resources, mentoring, and administrative expenses incurred by the Company during the training program.",
    this.terminationPoint6 =
        "Employees must maintain strict confidentiality and professionalism, and are prohibited from discussing or sharing any company-related information on personal or unofficial platforms. Any unauthorized communication, gossip, or actions that harm the company’s reputation will result in disciplinary action.",
    this.terminationPoint7 =
        "Employees are strictly prohibited from creating or maintaining any informal groups or communication channels without the knowledge and approval of the upper management. All official groups must be formed only with organizational consent, and any unauthorized group activity, discussion, or misconduct within such platforms will result in immediate disciplinary action as per company policy.",

    // Page 4
    // Moved Pre Employment Screening here
    this.preEmploymentScreeningTitle = "Pre Employment Screening",
    this.preEmploymentScreeningBody =
        "      This employment offer is contingent upon the successful completion of pre-employment screening activities, which may include background checks, reference checks of previous employment, and any other assessments deemed appropriate by the company. Please note that the company's policy states that any misrepresentation of qualifications, credentials, or other relevant information during the hiring process may result in immediate dismissal.",

    this.disputeTitle = "Dispute",
    this.disputeBody =
        "      Dispute Any dispute that arises between parties will be subjected to exclusive jurisdiction of courts in Chennai alone.",
    this.declarationTitle = "Declaration",
    this.declarationBody =
        "      During the onboarding process, you will be required to sign the 'Employment Service Agreement' documents, which outline the terms and conditions of the organization. If this is not completed, this Offer Letter will be considered void.",
    this.acceptanceConfirmation =
        "Please sign below as a confirmation of your acceptance and return it to the undersigned by {signdate}.",
  });

  // Factory constructor to create a PdfContentModel from a map (JSON)
  factory PdfContentModel.fromJson(Map<String, dynamic> json) {
    return PdfContentModel(
      dearName: json['dearName'] ?? "Dear {fullName},",
      intro: json['intro'],
      positionTitle: json['positionTitle'],
      positionBody: json['positionBody'],
      compensationTitle: json['compensationTitle'],
      compensationBody: json['compensationBody'],
      confidentialityTitle: json['confidentialityTitle'],
      confidentialityBody: json['confidentialityBody'],
      workingHoursTitle: json['workingHoursTitle'],
      workingHoursBody: json['workingHoursBody'],
      leaveEligibilityTitle: json['leaveEligibilityTitle'],
      leaveEligibilityBody: json['leaveEligibilityBody'],
      leaveAccrual: json['leaveAccrual'],
      publicHolidays: json['publicHolidays'],
      specialLeave: json['specialLeave'],
      addOnsForMen: json['addOnsForMen'],
      addOnsForWomen: json['addOnsForWomen'],
      leaveRequests: json['leaveRequests'],
      leaveResponsibly: json['leaveResponsibly'],
      leaveNote: json['leaveNote'],
      noticePeriodTitle: json['noticePeriodTitle'],
      noticePeriodBody: json['noticePeriodBody'],
      professionalConductTitle: json['professionalConductTitle'],
      professionalConductBody1: json['professionalConductBody1'],
      professionalConductBody2: json['professionalConductBody2'],
      terminationAndRecoveryTitle: json['terminationAndRecoveryTitle'],
      terminationPoint1: json['terminationPoint1'],
      terminationPoint2: json['terminationPoint2'],
      terminationPoint3: json['terminationPoint3'],
      terminationPoint4: json['terminationPoint4'],
      // New termination points
      terminationPoint5: json['terminationPoint5'],
      terminationPoint6: json['terminationPoint6'],
      terminationPoint7: json['terminationPoint7'],
      preEmploymentScreeningTitle: json['preEmploymentScreeningTitle'],
      preEmploymentScreeningBody: json['preEmploymentScreeningBody'],
      disputeTitle: json['disputeTitle'],
      disputeBody: json['disputeBody'],
      declarationTitle: json['declarationTitle'],
      declarationBody: json['declarationBody'],
      acceptanceConfirmation: json['acceptanceConfirmation'],
    );
  }

  // Method to convert a PdfContentModel instance to a map (JSON)
  Map<String, dynamic> toJson() {
    return {
      'dearName': dearName,
      'intro': intro,
      'positionTitle': positionTitle,
      'positionBody': positionBody,
      'compensationTitle': compensationTitle,
      'compensationBody': compensationBody,
      'confidentialityTitle': confidentialityTitle,
      'confidentialityBody': confidentialityBody,
      'workingHoursTitle': workingHoursTitle,
      'workingHoursBody': workingHoursBody,
      'leaveEligibilityTitle': leaveEligibilityTitle,
      'leaveEligibilityBody': leaveEligibilityBody,
      'leaveAccrual': leaveAccrual,
      'publicHolidays': publicHolidays,
      'specialLeave': specialLeave,
      'addOnsForMen': addOnsForMen,
      'addOnsForWomen': addOnsForWomen,
      'leaveRequests': leaveRequests,
      'leaveResponsibly': leaveResponsibly,
      'leaveNote': leaveNote,
      'noticePeriodTitle': noticePeriodTitle,
      'noticePeriodBody': noticePeriodBody,
      'professionalConductTitle': professionalConductTitle,
      'professionalConductBody1': professionalConductBody1,
      'professionalConductBody2': professionalConductBody2,
      'terminationAndRecoveryTitle': terminationAndRecoveryTitle,
      'terminationPoint1': terminationPoint1,
      'terminationPoint2': terminationPoint2,
      'terminationPoint3': terminationPoint3,
      'terminationPoint4': terminationPoint4,
      // New termination points
      'terminationPoint5': terminationPoint5,
      'terminationPoint6': terminationPoint6,
      'terminationPoint7': terminationPoint7,
      'preEmploymentScreeningTitle': preEmploymentScreeningTitle,
      'preEmploymentScreeningBody': preEmploymentScreeningBody,
      'disputeTitle': disputeTitle,
      'disputeBody': disputeBody,
      'declarationTitle': declarationTitle,
      'declarationBody': declarationBody,
      'acceptanceConfirmation': acceptanceConfirmation,
    };
  }
}
