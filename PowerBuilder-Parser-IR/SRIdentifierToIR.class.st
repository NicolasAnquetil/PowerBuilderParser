"
A specialization of SRIdentifierWithNode for IREntities

Instance variables:
- chainedOwner, the owning entity where to create a missing chained one (e.g. in `this.a.b` if `b` is not found, it must be created in `a`, not in the currentEntity)

It has convenient methods to create default #foundAction: and #notFoundReplacementEntity: blocks
By default #foundAction: creates a dependency from 'currentEntity' to the entity found
By default #notFoundReplacementEntity: creates a stub IREntity for the identifier not found
"
Class {
	#name : #SRIdentifierToIR,
	#superclass : #SRIdentifierWithNode,
	#instVars : [
		'chainedOwner',
		'referenceIsAssigned'
	],
	#category : #'PowerBuilder-Parser-IR-symbolResolver'
}

{ #category : #accessing }
SRIdentifierToIR >> chainedOwner [
	^ chainedOwner
]

{ #category : #accessing }
SRIdentifierToIR >> chainedOwner: anObject [
	chainedOwner := anObject
]

{ #category : #hooks }
SRIdentifierToIR >> ifFoundCreateDependencyInModel: irModel [
	"Action block called by SymbolResolver when identifier to resolve is found
	 Default is to create a dependency from the currentEntity to the entity found"
	self foundAction: [ :me :currentEntity | 
			(self entity addReferenceBy: currentEntity inModel: irModel)
				isWrite: referenceIsAssigned ]
]

{ #category : #hooks }
SRIdentifierToIR >> ifNotFoundCreateFromChainInModel: irModel [
	"Action block called by SymbolResolver if an identifier to resolve is not found
	 This one is for an identifier second or more in a chain (a.b.c)
	therefore, it must be created in its owner (eg: in a for b) which is set in 
	instance variable chainedOwner"

	self notFoundReplacementEntity: [ :me :currentEntity |
		(irModel
			ensureIR: self mainIRKind
			named: self identifier
			owner: self chainedOwner)

			expectedFamixKinds: (self expectedKind) ;
			yourself ]

]

{ #category : #hooks }
SRIdentifierToIR >> ifNotFoundCreateStubInModel: irModel [
	"Action block called by SymbolResolver if an identifier to resolve is not found
	 Default is to create a stub entity with the right kind"

	self notFoundReplacementEntity: [ :me :currentEntity |
		(irModel irStub: self mainIRKind named: self identifier)
			expectedFamixKinds: (self expectedKind) ;
			yourself ]
]

{ #category : #resolution }
SRIdentifierToIR >> initialize [ 
	super initialize.
	referenceIsAssigned := false
]

{ #category : #hooks }
SRIdentifierToIR >> mainFamixKind [
	^self expectedKind isCollection
		ifTrue: [ self expectedKind first ]
		ifFalse: [ self expectedKind ]
]

{ #category : #hooks }
SRIdentifierToIR >> mainIRKind [
	^PWBIRNamedEntity irClassForFamixClass: self mainFamixKind
]

{ #category : #accessing }
SRIdentifierToIR >> referenceIsAssigned [
	"State that the referenced identifier is assigned
	 therefore this is a write access to a variable"
	self isLast
	ifTrue: [ referenceIsAssigned := true ]
	ifFalse: [ self next referenceIsAssigned ]
]