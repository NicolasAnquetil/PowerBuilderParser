Class {
	#name : #PWBTypeDeclarationVisitor,
	#superclass : #PWBAbstractAuxiliaryVisitor,
	#category : #'PowerBuilder-Parser-Visitor-visitors'
}

{ #category : #'ir entities' }
PWBTypeDeclarationVisitor >> ensureTypeNamed: typeIdentifier withSuper: superIdentifier [
	| irType |
	(self isMainEntityOfCurrentFile: typeIdentifier identifier)
		ifTrue: [ ^ self currentEntity ].
	irType := self model
		ensureIR: PWBIRType
		named: typeIdentifier identifier
		owner: self currentEntity.
	irType expectedFamixKinds
		ifNil: [ irType setExpectedFamixKindsToDefault ].

	superIdentifier
		ifNotNil: [
			self superType: superIdentifier forIrType: irType.
		].
	^ irType
]

{ #category : #'famix kind' }
PWBTypeDeclarationVisitor >> famixTypeKindFromFileExtension [
	"expected famix kind of a PWB type with the same name as its containing file
	We get the famix class associated to the extension, then check it corresponds to a PWB type"
	| famixKind |
	famixKind := self famixClassForFileExtension: self file extension.
	^(PWBIRType defaultFamixClasses includes: famixKind) 
	ifTrue: [ famixKind ]
	ifFalse: [ nil ]
]

{ #category : #'famix kind' }
PWBTypeDeclarationVisitor >> getSuperType: superName [
	(self model getAllIR: PWBIRType named: superName)
		ifEmpty: [
			^(self model irStub: PWBIRType named: superName)
				setExpectedFamixKindsToDefault ;
				yourself.
		]
		ifNotEmpty: [ :superCandidates |
			"hopefully there is only one ..."
			^superCandidates anyOne
		]
]

{ #category : #visiting }
PWBTypeDeclarationVisitor >> importType: importedName fromOwner: ownerIdentifier [
	"import means we have access to an external type just has if it was define in the file
	 Several things to do:
	 - ensure a PWBIRType (importedName) in the type ownerIdentifier
	   resolve its type name as if it was ownerIdentifier.importedName
	 - ensure a PWBIRImportedType (importedName) in currentEntity. It points to the PWBIRType
	"
	| irAlias firstSRIdentifier secondSRIdentifier |

	"ensure the importedType"
	irAlias := self model
			ensureIR: PWBIRImportedType
			named: importedName
			owner: self currentEntity.

	"now create the identifier ownerIdentifier.importedName"
	firstSRIdentifier := (SRIdentifierToIR
		name: ownerIdentifier identifier
		expectedKind: PWBIRType defaultFamixClasses
		node: ownerIdentifier)
		ifNotFoundCreateStubInModel: (self model) ;
		foundAction: [ :identifier :currentEntity |
			identifier next chainedOwner: identifier entity ] ;
		yourself.
	secondSRIdentifier := (SRIdentifierToIR
		name: importedName
		expectedKind: PWBIRType defaultFamixClasses
		node: nil)
		foundAction: [ :identifier :currentEntity | irAlias importedType: identifier entity ] ;
		ifNotFoundCreateFromChainInModel: (self model).
	firstSRIdentifier next: secondSRIdentifier.

	self resolve: (self resolvable: firstSRIdentifier).

	^irAlias

]

{ #category : #testing }
PWBTypeDeclarationVisitor >> isExternallyDefinedType: aPWBASTWithinClause [
	^ aPWBASTWithinClause
		ifNil: [ false ]
		ifNotNil: [
			(self isMainEntityOfCurrentFile: aPWBASTWithinClause customType identifier identifier)
				not
		]
]

{ #category : #testing }
PWBTypeDeclarationVisitor >> isMainEntityOfCurrentFile: typeName [
	^(typeName = (self file basename allButLast: 4)) and:
	[ typeName = (self currentEntity name) ] "i.e. we are in top scope of this file"
]

{ #category : #'ir entities' }
PWBTypeDeclarationVisitor >> superType: typeIdentifier forIrType: irType [
	| resolvable |
	resolvable := self
		resolvable:
			(SRIdentifierToIR
				name: typeIdentifier identifier
				expectedKind: irType expectedFamixKinds
				node: typeIdentifier).
	resolvable
		foundAction:
				[ :identifier :currentEntity | irType superType: identifier entity ];
		ifNotFoundCreateStubInModel: self model.
	self resolve: resolvable
]

{ #category : #testing }
PWBTypeDeclarationVisitor >> testRedefinesAttributesValuesOfKnownType: aPWBASTTypeDeclaration [
	"syntax: 'type <aType> from <superType>`<innerType> ...'
	indicates a redefinition of some attributes value in innerType member of superType
	This is marked in the AST by the #eventType member"
	^aPWBASTTypeDeclaration eventType isNotNil

]

{ #category : #visiting }
PWBTypeDeclarationVisitor >> visitPWBASTFromClause: aPWBASTFromClause [
	^self auxiliaryVisitor: PWBTypeReferenceToIdentifierVisitor visit: aPWBASTFromClause customType.
]

{ #category : #visiting }
PWBTypeDeclarationVisitor >> visitPWBASTTypeDeclaration: aPWBASTTypeDeclaration [
	| irType |
	(self testRedefinesAttributesValuesOfKnownType: aPWBASTTypeDeclaration)
	ifTrue: [ ^self ].

	irType :=
	(self isExternallyDefinedType: aPWBASTTypeDeclaration withinClause)
		ifTrue: [
			(self
				importType: aPWBASTTypeDeclaration type identifier identifier
				fromOwner: aPWBASTTypeDeclaration withinClause customType identifier)
				setSourceAnchorFrom: aPWBASTTypeDeclaration file: self file ]
		ifFalse: [
			(self
				ensureTypeNamed: (aPWBASTTypeDeclaration type identifier)
				withSuper: aPWBASTTypeDeclaration fromClause customType identifier)
				setSourceAnchorFrom: aPWBASTTypeDeclaration file: self file
		].

	self visit: aPWBASTTypeDeclaration descriptor.

	(irType = self currentEntity)
	ifTrue: [ self visit: aPWBASTTypeDeclaration attributes ]
	ifFalse: [
		self
			useCurrentEntity: irType
			during: [ self visit: aPWBASTTypeDeclaration attributes ]
	]

]

{ #category : #visiting }
PWBTypeDeclarationVisitor >> visitPWBASTVariableDeclarations: aPWBASTVariableDeclarations [
	"definition of instance variables of whartever type we are currently decalring,
	PWBTypeDeclarationVisitor can handle that"
	^self auxiliaryVisitor: PWBVariableDeclarationVisitor visit: aPWBASTVariableDeclarations
]