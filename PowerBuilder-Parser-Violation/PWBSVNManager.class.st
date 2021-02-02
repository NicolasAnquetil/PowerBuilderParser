Class {
	#name : #PWBSVNManager,
	#superclass : #SpPresenter,
	#instVars : [
		'repoUrl',
		'diff',
		'lines',
		'svnHead',
		'repoUrlTextInput'
	],
	#category : #'PowerBuilder-Parser-Violation'
}

{ #category : #specs }
PWBSVNManager class >> defaultSpec [
	^ SpBoxLayout newVertical
		add: #repoUrlTextInput;
		yourself
]

{ #category : #running }
PWBSVNManager class >> run [
	<example>
	^ self new openWithSpec
]

{ #category : #running }
PWBSVNManager class >> run: aSVNRepoURL [
	self new
		repoUrl: aSVNRepoURL;
		run
]

{ #category : #'as yet unclassified' }
PWBSVNManager >> diffFilesUrls [
	| prev |
	"self getSvnHEADNumber."
	prev := svnHead - 1.
	diff := LibC
		resultOfCommand:
			'svn diff -r ' , prev asString , ':' , svnHead asString , String space
				, repoUrl , ' --summarize'.
	lines := diff lines asOrderedCollection
		reject: [ :line | 
			(line beginsWith: 'D')
				or: [ {'.pbl' . '.pbd' . '.pbg' . 'pbt' . '.srd' . '.sra'}
						anySatisfy: [ :extension | line endsWith: extension ] ] ]
		thenCollect: [ :e | e copyFrom: 9 to: e size ].
	^ lines
]

{ #category : #'as yet unclassified' }
PWBSVNManager >> downloadDiffFilesForHeadAndPrev [
	| diffFiles |
	diffFiles := self diffFilesUrls.
	self
		downloadFiles: diffFiles
		rev: svnHead - 1
		dest: (self ensureCreateDirStructure: 'svnPrev') pathString.
	self
		downloadFiles: diffFiles
		rev: svnHead
		dest: (self ensureCreateDirStructure: 'svnHead') pathString
]

{ #category : #'as yet unclassified' }
PWBSVNManager >> downloadFiles: diffFiles rev: anInteger dest: aString [
	diffFiles
		do: [ :file | 
			| command |
			command := 'svn export -r ' , anInteger asString , String space
				, file , String space , aString.
			LibC resultOfCommand: command ]
]

{ #category : #'as yet unclassified' }
PWBSVNManager >> ensureCreateDirStructure: aString [
	| dest |
	(FileSystem workingDirectory / aString) ensureDeleteAll.
	(FileSystem workingDirectory / aString) ensureCreateDirectory.
	dest := FileSystem workingDirectory / aString / 'lib'.
	^ dest ensureCreateDirectory
]

{ #category : #'as yet unclassified' }
PWBSVNManager >> getSvnHEADNumber [
	| info |
	info := LibC resultOfCommand: 'svn info ' , repoUrl , ' --xml'.
	svnHead := (((XMLDOMParser parse: info) document
		descendantElementsDetect: [ :xmlElt | xmlElt name = 'commit' ])
		attributeNodeAt: 'revision') value asInteger.
	^ svnHead
]

{ #category : #initialization }
PWBSVNManager >> initialize [
	super initialize.
	repoUrl := 'https://CIM-SVN.SA-CIM.local/svn/TestCI/'
]

{ #category : #initialization }
PWBSVNManager >> initializePresenters [
	repoUrlTextInput := self instantiate: SpLabelledTextInput.
	repoUrlTextInput acceptOnCR: true.
	repoUrlTextInput
		label: 'SVN repository URL:';
		whenTextIsAccepted: [ repoUrl := repoUrlTextInput text.
			self window close.
			self run ]
]

{ #category : #initialization }
PWBSVNManager >> initializeWindow: aWindowPresenter [

	aWindowPresenter 
		title: 'PWB Violation Manager';
		initialExtent: 500@100
]

{ #category : #accessing }
PWBSVNManager >> repoUrl: aSVNRepoURL [
	repoUrl := aSVNRepoURL
]

{ #category : #'as yet unclassified' }
PWBSVNManager >> run [
	| lastHead |
	[ [ true ]
		whileTrue: [ lastHead := svnHead.
			self getSvnHEADNumber.
			svnHead = lastHead
				ifFalse: [ self runViolations ].
			(Duration minutes: 1) asDelay wait ] ] fork
]

{ #category : #'as yet unclassified' }
PWBSVNManager >> runViolations [
	self downloadDiffFilesForHeadAndPrev.
	^ (PWBSVNDiffViolationManager
		prev:
			(ViolationRunner
				importFromFolder: FileSystem workingDirectory / 'svnPrev')
				violations
		head:
			(ViolationRunner
				importFromFolder: FileSystem workingDirectory / 'svnHead')
				violations) publishDiff
]