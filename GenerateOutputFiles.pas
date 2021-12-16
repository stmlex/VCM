const LOG_FILE_NAME ='Build.log';
const JOB_FILE_NAME ='Build.OutJob';
const PROJECT_TITLE ='ProjectTitle';
const PROJECT_PART_NUMBER ='ProjectPartNumber';
const PROJECT_REVISION ='ProjectRevision';
// Global variables
Var
   gWorkSpace : IWorkspace;
   gProject : IProject;
   gProjectFilePath : String;
   gProjectTitle : String;
   gProjectRevision : String;
   gProjectPartNumber : String;

Procedure ExitAltium();
Begin
     RunApplication('taskkill /im x2.exe');
End;

Function StringifyDecimalName() : String;
Begin
  Result := gProjectPartNumber + '-' + gProjectRevision;
End;

Procedure LogInit();
Var
  logfile                     : TextFile;
Begin
  AssignFile(logfile, ExtractFilePath(gProjectFilePath) + LOG_FILE_NAME);
  ReWrite(logfile);
  CloseFile(logfile);
End;

Function GetProjectOptionValue(Name : String) : String;
Var
  Par : IParameter;
Begin
  Par := gProject.DM_GetParameterByName(Name);
  Result := gProject.DM_GetStringParameterValue(Name);
  //Result := Par.DM_CalculateParameterValue(Par);
End;

Procedure Init();
Var
  projectCount : Integer;
begin

  gWorkSpace := GetWorkspace;
  If (gWorkSpace = Nil) Then
    Begin
      ExitAltium();
    End;

  projectCount := gWorkSpace.DM_ProjectCount();

  if (projectCount = 0) Then
    Begin
      ExitAltium();
    End;

  // NOTE: Expecting only one project to be open.
  gProject := gWorkSpace.DM_Projects(1);
  //gProject := gWorkSpace.DM_FocusedProject;
  // See if we found our script project.
  If (gProject.DM_ProjectFullPath <> 'Free Documents') Then
    Begin
      // Strip off project name to give us just the path.
      gProjectFilePath := gProject.DM_ProjectFullPath;
    End;

  gProjectTitle := GetProjectOptionValue(PROJECT_TITLE);
  gProjectPartNumber := GetProjectOptionValue(PROJECT_PART_NUMBER);
  gProjectRevision := GetProjectOptionValue(PROJECT_REVISION);

  LogInit();
end;

Function AppendToFile(f : TextFile; msg : String);
Begin
  Append(f);
  WriteLn(f, msg);
  CloseFile(f);
End;

Procedure LogWrite(msg : String);
Var
  logfile                     : TextFile;
Begin
  AssignFile(logfile, ExtractFilePath(gProjectFilePath) + LOG_FILE_NAME);
  AppendToFile(logfile, DateTimeToStr(Now) + ': ' + msg);
End;

Procedure GenerateReport(job_name : String);
Begin
  LogWrite('Generating report: ' + job_name);
  ResetParameters;
  AddStringParameter('ObjectKind', 'OutputBatch');
  AddStringParameter('DisableDialog', 'True');
  AddStringParameter('OutputMedium', job_name);
  AddStringParameter('Action', 'Run');
  RunProcess('WorkSpaceManager:GenerateReport');
End;

Procedure PublishToPDF(job_name : String);
Begin
  LogWrite('Generating report: ' + job_name);
  ResetParameters;
  AddStringParameter('ObjectKind', 'OutputBatch');
  AddStringParameter('DisableDialog', 'True');
  AddStringParameter('OutputMedium', job_name);
  AddStringParameter('Action', 'PublishToPDF');
  RunProcess('WorkSpaceManager:Print');
End;

Procedure GenerateBuildVariant(variant : String, Build_OutJob : IWSM_OutputJobDocument);
Begin
  Build_OutJob.VariantName := variant;
  Client.ShowDocument(Build_OutJob);
  PublishToPDF('3DPDF');
  GenerateReport('BOM');
  PublishToPDF('Scheme');
  PublishToPDF('Assembly');
  GenerateReport('CAD');
  GenerateReport('PCB');
  PublishToPDF('PCB_construction');
  GenerateReport('Pick&Place');
  GenerateReport('Manufacturing');
End;

// Generate output files for build and release system
Procedure GenerateBuildOutputs();
Var
  Build_OutJob                : IWSM_OutputJobDocument;
  PrjVar                      : Integer;
  PrjVarCnt                   : Integer;
  VariantName                 : String;
  PrjOutputPath               : String;
  IsPrjCompiled               : LongBool;

Begin
  // Set the Project file path
  //ProjectFilePath := ScriptProjectPath();

  LogWrite('Altium Designer build process started.');
  LogWrite('Project file path discovered as ' + gProjectFilePath);

  ResetParameters;

  // Open the project
  AddStringParameter('ObjectKind','Project');
  AddStringParameter('FileName', gProjectFilePath);
  RunProcess('WorkspaceManager:OpenObject');
  ResetParameters;
  LogWrite('Project has been opened.');

  Build_OutJob := Client.OpenDocument('OUTPUTJOB', ExtractFilePath(
                  gProjectFilePath) + JOB_FILE_NAME);
  If Build_OutJob = Nil Then
    Begin
      LogWrite('ERROR: Build_OutJob is empty. Exiting with error code.');
      ExitAltium();
    End;

  IsPrjCompiled := gProject.DM_Compile;
  If IsPrjCompiled <> 1 Then //FIXME this doesn't work
  Begin
    LogWrite('ERROR: Compile failed.');
    ExitAltium();
  End;

  LogWrite('Project has been compiled.');
  PrjVarCnt := gProject.DM_ProjectVariantCount;
  PrjOutputPath := gProject.DM_GetOutputPath;
  if PrjVarCnt = 0 Then
    Begin
      LogWrite('Generating Files');
      GenerateBuildVariant('[No Variations]', Build_OutJob);
      RenameFile(PrjOutputPath, StringifyDecimalName());
    End
  Else
    Begin
      For PrjVar:=0 to PrjVarCnt-1 Do
        Begin
          VariantName := gProject.DM_ProjectVariants(PrjVar).DM_Description;
          LogWrite('Generating Variant: ' + VariantName);
          GenerateBuildVariant(VariantName, Build_OutJob);
          RenameFile(PrjOutputPath, StringifyDecimalName() + '-' + VariantName);
        End;
    End;
  // Close and save all objects
  ResetParameters;
  AddStringParameter('ObjectKind','All');
  AddStringParameter('ModifiedOnly','True');
  RunProcess('WorkspaceManager:SaveObject');
  RunProcess('WorkspaceManager:CloseObject');
  ResetParameters;
  LogWrite('All objects closed.');
End;

Procedure GenerateOutputFiles;
Begin
  Init();
  LogWrite(PROJECT_TITLE +': ' + gProjectTitle);
  LogWrite(PROJECT_PART_NUMBER +': ' + gProjectPartNumber);
  LogWrite(PROJECT_REVISION +': ' + gProjectRevision);
  GenerateBuildOutputs();
  LogWrite('Bye for now...');
  ExitAltium();
End;
