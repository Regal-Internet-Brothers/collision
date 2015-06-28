Strict

Public

' Preprocessor related:
' Nothing so far.

' Imports (Public):

' Unofficial:
Import polygon
Import vector

' Imports (Private):
Private

' Official:
Import brl.pool

Public

' Interfaces:

' This is used to feed detailed information into a 'CollisionEngine'.
Interface CollisionParent
	' Methods:
	' Nothing so far.
	
	' Properties:
	
	' Vectors:
	Method Collision_Position:Vector2D<Float>() Property
	Method Collision_Velocity:Vector2D<Float>() Property
	
	' Flags / Booleans:
	Method Collision_IsStatic:Bool() Property
	Method Collision_IsPushable:Bool() Property
	
	' Meta:
	Method Collision_Mass:Float() Property
	Method Collision_InvMass:Float() Property
	
	Method Collision_Restitution:Float() Property
End

' Classes:
Class CollisionInfo
	' Constant variable(s):
	
	' Defaults:
	
	' Booleans / Flags:
	Const Default_AContained:Bool = True
	Const Default_BContained:Bool = Default_AContained ' True
	
	' Constructor(s):
	Method New()
		AllocVectors()
	End
	
	' This will allocate vectors from 'Allocator'.
	Method New(Allocator:CollisionEngine)
		AllocVectors(Allocator)
	End
	
	Method New(A:Polygon, B:Polygon, AContained:Bool=Default_AContained, BContained:Bool=Default_BContained)
		AllocVectors()
		
		Self.A = A
		Self.B = B
		
		Self.AContained = AContained
		Self.BContained = BContained
	End
	
	Method AllocVectors:Void()
		Self.Vector = New Vector2D<Float>()
		Self.Separation = New Vector2D<Float>()
		
		Return
	End
	
	Method AllocVectors:Void(Allocator:CollisionEngine)
		Self.Vector = Allocator.AllocateVector()
		Self.Separation = Allocator.AllocateVector()
		
		Return
	End
	
	Method ReverseOf:Void(C:CollisionInfo)
		Self.A = C.A
		Self.B = C.B
		
		Self.AContained = C.BContained
		Self.BContained = C.AContained
		
		Self.Distance = C.Distance
		
		Self.Vector.Assign(C.Vector)
		Self.Vector.Negate()
		
		Self.Separation.Assign(C.Separation)
		Self.Separation.Negate()
		
		Return
	End
	
	' Destructor(s):
	Method Free:CollisionInfo()
		Self.A = Null
		Self.B = Null
		
		Self.Vector.Zero()
		Self.Separation.Zero()
		
		Self.Distance = 0.0
		
		Self.AContained = Default_AContained
		Self.BContained = Default_BContained
		
		' Return this object so it may be pooled.
		Return Self
	End
	
	' Methods:
	Method CalculateSeparation:Void()
		' Calculate the MTV (AKA the 'Separation' vector):
		Separation.Copy(Vector)
		Separation.Multiply(Distance)
		
		Return 
	End
	
	Method CalculateSeparation:Void(Target:CollisionInfo)
		CalculateSeparation()
		
		If (Target <> Null) Then
			Target.AContained = (AContained And Target.AContained)
			Target.BContained = (BContained And Target.BContained)
		Endif
		
		Return
	End
	
	' Properties:
	Method MTV:Vector2D<Float>() Property
		Return Separation
	End
	
	Method MinimumTranslationVector:Vector2D<Float>() Property
		Return MTV
	End
	
	' This property may change in the future.
	Method Normal:Vector2D<Float>() Property
		Return Vector
	End
	
	' Fields:
	Field A:Polygon
	Field B:Polygon
	
	Field AParent:CollisionParent
	Field BParent:CollisionParent
	
	Field Vector:Vector2D<Float>
	Field Separation:Vector2D<Float>
	
	Field Distance:Float
	
	' Booleans / Flags:
	Field AContained:Bool
	Field BContained:Bool
End

#Rem
Class Projection Extends Vector2D<Float> ' Final
	' Constructor(s):
	Method New()
		Init()
	End
	
	Method Init:Projection()
		Min = 0.0
		Max = 0.0
		
		' Return this object for pooling.
		Return Self
	End
	
	' Destructor(s):
	Method Free:Projection()
		'Return Init()
		
		Return Self
	End
	
	' Methods:
	Method ProjectToPoints:Projection(Axis:Vector2D<Float>, Points:Vector2D<Float>[])
		Min = Axis.DotProduct(Points[0]); Max = Min
		
		For Local I:= 1 Until Points.Length()
			' Local variable(s):
			Local P:Float = Axis.DotProduct(Points[I])
			
			If (P < Min) Then
				Min = P
			Elseif (P > Max) Then
				Max = P
			Endif
		Next
		
		' Now that we've calculated the 'interval', return this projection.
		Return Self
	End
	
	Method Overlap:Bool(P:Projection)
		'If (Max > P.Min And P.Max > Min) Then Return True
		
		' This one works.
		If (Max > P.Min And Min < P.Max) Then Return True
		'If (lang.Max(Max, P.Max) > lang.Min(Min, P.Min)) Then Return True
		
		'If ((Min - P.Max) > 0) Then Return False
		'If ((P.Min - Max) > 0) Then Return False
		
		'Return True
		
		' Return the default response.
		Return False
	End
	
	Method Enlarge:Float(Amount:Float)
		Min -= Amount
		Max += Amount
		
		Return Amount
	End
	
	' Properties (Public):
	Method Min:Float() Property
		Return X
	End
	
	Method Max:Float() Property
		Return Y
	End
	
	Method Min:Void(Input:Float) Property
		X = Input
		
		Return
	End
	
	Method Max:Void(Input:Float) Property
		Y = Input
		
		Return
	End
	
	' Fields:
	' Nothing so far.
End
#End

Class CollisionEngine
	' Constant variable(s):
	
	' Defaults:
	Const Default_VectorCacheSize:Int = 8
	Const Default_ResponseCacheSize:Int = 2
	
	Const Default_TimeStep:Int = 4 ' 8 ' 6 ' 10 ' 12
	
	' Other:
	Const MAX_VALUE:Float = 99999999999999.0
	
	' Functions:
	Function DotProduct:Float(A_X:Float, A_Y:Float, B_X:Float, B_Y:Float)
		Return (A_X*B_X) + (A_Y*B_Y)
	End
	
	Function IsZero:Bool(X:Vector2D<Float>)
		Return ((X.X = 0.0) And (X.Y = 0.0))
	End
	
	' Constructor(s):
	Method New(VectorCacheSize:Int=Default_VectorCacheSize, ResponseCacheSize:Int=Default_ResponseCacheSize)
		Self.VectorPool = New Pool<Vector2D<Float>>(VectorCacheSize)
		Self.ResponsePool = New Pool<CollisionInfo>(ResponseCacheSize)
		
		Self.CollisionAxes = New Stack<Vector2D<Float>>()
	End
	
	' Methods (Public):
	
	' This command is best used for detailed collision resolution routines.
	' Using this as if it produces a boolean will result in unnecessary garbage. For a simple one-off check, use 'CollisionOccurred'.
	Method CheckCollision:CollisionInfo(X:Polygon, Y:Polygon, XParent:CollisionParent, YParent:CollisionParent, Delta:Float=1.0, TimeStep:Int=Default_TimeStep)
		' Make sure we aren't checking against our self.
		'If (X = Y) Then Return Null
		
		' Map the context to the axes of 'X'.
		MapAxes(X)
		
		' Test for collision:
		Local FirstResponse:= CheckOverlap(X, Y, XParent, YParent, Delta, TimeStep, False, True)
		
		' Check if there wasn't a response.
		If (FirstResponse = Null) Then
			' Return nothing.
			Return Null
		Endif
		
		' Map the context to the axes of 'Y'.
		MapAxes(Y)
		
		' Check the opposite situation.
		Local SecondResponse:= CheckOverlap(Y, X, XParent, YParent, Delta, TimeStep, True, True)
		
		' If there was an error while calculating the second response,
		' toss the other object, and return nothing:
		If (SecondResponse = Null) Then
			Deallocate(FirstResponse)
			
			' Return nothing.
			Return Null
		Endif
		
		' Find the proper response object:
		If (FirstResponse.Distance < SecondResponse.Distance) Then
		'If (FirstResponse.ShortestOverlap < SecondResponse.ShortestOverlap) Then
			FirstResponse.CalculateSeparation(SecondResponse)
			
			Deallocate(SecondResponse)
			
			Return FirstResponse
		Endif
		
		SecondResponse.CalculateSeparation(FirstResponse)
		
		Deallocate(FirstResponse)
		
		Return SecondResponse
	End
	
	Method CheckOverlap:CollisionInfo(X:Polygon, Y:Polygon, XParent:CollisionParent, YParent:CollisionParent, Delta:Float=1.0, TimeStep:Int=Default_TimeStep, Flip:Bool=False, CalculateDetails:Bool=True)
		' Local variable(s):
		Local Response:= AllocateCollisionResponse()
		
		If (Flip) Then
			Response.A = Y
			Response.B = X
			
			Response.AParent = XParent
			Response.BParent = YParent
		Else
			Response.A = X
			Response.B = Y
			
			Response.AParent = YParent
			Response.BParent = XParent
		Endif
		
		Local P1:= AllocateRawVector()
		Local P2:= AllocateRawVector()
		
		Local OverlapFound:Bool = True
		
		For Local CurrentStep:= 0 Until TimeStep
			OverlapFound = True
			
			' Local variable(s):
			Local ShortestOverlap:Float = MAX_VALUE
			
			For Local Axis:= Eachin CollisionAxes
				' Calculate the proper projections for this axis:
				ProjectToPoints(Y, P1, Axis, X, XParent, Delta, CurrentStep)
				ProjectToPoints(X, P2, Axis, Y, YParent, Delta, CurrentStep)
				
				' Check if there wasn't an overlap:
				If (Not ProjectionOverlap(P1, P2)) Then
					OverlapFound = False
					
					Exit
				Endif
				
				' Local variable(s):
				'Local O:Float = Projection.Distance(P1, P2)
				
				If (CalculateDetails) Then
					' Check which polygon is contained:
					If (Flip) Then
						If (P1.Y < P2.Y Or P1.X > P2.X) Then
							Response.AContained = False
						Endif
						
						If (P2.Y < P1.Y Or P2.X > P1.X) Then
							Response.BContained = False
						Endif
					Else
						If (P1.Y > P2.Y Or P1.X < P2.X) Then
							Response.AContained = False
						Endif
						
						If (P2.Y > P1.Y Or P2.X < P1.X) Then
							Response.BContained = False
						Endif
					Endif
					
					Local Overlap:Float
					
					If (Not Flip) Then
						Overlap = (P1.Y - P2.X) ' (Min(P1.Max, P2.Max) - Max(P1.Min, P2.Min))
					Else
						Overlap = (P2.Y - P1.X) ' (Min(P1.Max, P2.Max) - Max(P1.Min, P2.Min))
					Endif
					
					' Find the smallest overlap-distance.
					If (Overlap < ShortestOverlap) Then ' AbsOverlap < ShortestOverlap
						Response.Distance = Abs(Overlap) ' Overlap
						Response.Vector.Assign(Axis)
						
						ShortestOverlap = Overlap ' AbsOverlap
					Endif
				Endif
			Next
			
			If (OverlapFound) Then
				Exit
			Endif
		Next
		
		Deallocate(P1)
		Deallocate(P2)
		
		If (Not OverlapFound) Then
			Deallocate(Response)
			
			' No overlap was detected, return nothing.
			Return Null
		Endif
		
		' Return the calculated response-object.
		Return Response
	End
	
	Method ResolveCollision:Bool(CollisionResult:CollisionInfo, X:Polygon, Y:Polygon, XParent:CollisionParent, YParent:CollisionParent, TimeStep:Int=Default_TimeStep, Delta:Float=1.0, CorrectionPercentage:Float=0.8, CorrectionSlop:Float=0.2)
		' Local variable(s):
		Local Position:= XParent.Collision_Position
		Local TargetPosition:= YParent.Collision_Position
		
		Local Velocity:= XParent.Collision_Velocity
		Local TargetVelocity:= YParent.Collision_Velocity
		
		' Read-only; use with caution.
		Local Normal:= CollisionResult.Normal
		
		' Local variable(s):
		
		' Calculate the relative velocity:
		Local RelativeVelocity:= AllocateRawVector() ' AllocateVector()
		
		RelativeVelocity.Copy(TargetVelocity)
		RelativeVelocity.Subtract(Velocity)
		
		' Calculate the angular velocity based on the normal:
		Local AngularVelocity:Float = RelativeVelocity.DotProduct(Normal)
		
		' We no longer need our relative velocity vector, get rid of it.
		Deallocate(RelativeVelocity)
		
		' Don't resolve if the velocities are separating:
		If (Not XParent.Collision_IsStatic) Then
			If (AngularVelocity > 0.0) Then
				Return False
			Endif
		Endif
		
		' Ensure at least one of our elements isn't static:
		If (Not XParent.Collision_IsStatic Or Not YParent.Collision_IsStatic) Then
			' Retrieve the 'inverted' masses:
			Local InvMass:Float = XParent.Collision_InvMass
			Local InvTargetMass:Float = YParent.Collision_InvMass
			
			' Calculate the restitution.
			Local e:Float = Min(XParent.Collision_Restitution, YParent.Collision_Restitution)
			
			' Calculate the impulse scalar:
			Local j:Float = -(1.0 + e) * (AngularVelocity)
			
			j /= (InvMass + InvTargetMass)
			
			Local Mass:Float = XParent.Collision_Mass ' (1.0/InvMass)
			Local TargetMass:Float = YParent.Collision_Mass ' (1.0/InvTargetMass)
			Local Mass_Sum:Float = (Mass + TargetMass)
			
			' Allocate an impulse vector.
			Local Impulse:= AllocateRawVector() ' AllocateVector()
			
			If (Not XParent.Collision_IsStatic) Then
				Impulse.Copy(Normal)
				Impulse.Multiply(j)
				
				' Apply the impulse:
				Impulse.Multiply(InvMass * (Mass_Sum / Mass)) ' (Mass_Sum / Mass)
				
				Velocity.Subtract(Impulse)
				'Position.Add(Impulse)
			Endif
			
			If (YParent.Collision_IsPushable) Then ' And Not Target.Parent.Collision_IsStatic
				Impulse.Copy(Normal)
				Impulse.Multiply(j)
				
				' Apply the impulse:
				Impulse.Multiply(InvTargetMass * (TargetMass / Mass_Sum)) ' (Mass_Sum / TargetMass)
				
				TargetVelocity.Add(Impulse)
				'TargetPosition.Subtract(Impulse)
			Endif
			
			' Deallocate our impulse vector.
			Deallocate(Impulse)
			
			Local InvMass_Sum:Float = (InvMass + InvTargetMass)
			
			' Generate an initially shared correction-vector:
			Local Correction:= CopyVector(CollisionResult.MTV)
			
			' Perform common operations on the main correction-vector:
			
			' Ensure the initial force applied is absolute.
			Correction.Absolute()
			
			' Apply the described "slop".
			Correction.Subtract(CorrectionSlop)
			
			' Cap our correction, doing nothing if invalid:
			Correction.ApplyMax(0.0)
			
			' Ensure we have a correction to apply:
			If (Not IsZero(Correction)) Then
				Correction.Divide(InvMass_Sum) ' InvMass_Sum  * CorrectionPercentage
				
				' Scale down the correction based on the described percentage.
				Correction.Multiply(CorrectionPercentage)
				
				' Apply the direction of the collision-normal.
				Correction.Multiply(Normal)
				
				If (Not XParent.Collision_IsStatic) Then
					' Generate a correction-vector for 'X':
					Local XCorrection:= CopyVector(Correction)
					
					XCorrection.Multiply(InvMass)
					
					'Velocity.Subtract(XCorrection)
					Position.Subtract(XCorrection)
					
					' Deallocate the correction for 'X'.
					Deallocate(XCorrection)
				Endif
				
				If (Not YParent.Collision_IsStatic) Then
					' Calculate the correction for 'Y':
					Correction.Multiply(InvTargetMass)
					
					'TargetVelocity.Add(XCorrection)
					TargetPosition.Add(Correction)
				Endif
			Endif
			
			' Deallocate the main correction-vector.
			Deallocate(Correction)
		Endif
		
		' Return the default response.
		Return True
	End
	
	' Projection functionality:
	
	' When using this overload, you must deallocate the output when finished.
	Method ProjectToPoints:Vector2D<Float>(TargetPolygon:Polygon, Axis:Vector2D<Float>, Polygon:Polygon, Parent:CollisionParent, Delta:Float=1.0, TimeStep:Int=Default_TimeStep)
		Local P:= AllocateRawVector()
		
		ProjectToPoints(TargetPolygon, P, Axis, Polygon, Parent, Delta, TimeStep)
		
		Return P
	End
	
	Method ProjectToPoints:Void(TargetPolygon:Polygon, P:Vector2D<Float>, Axis:Vector2D<Float>, Polygon:Polygon, Parent:CollisionParent, Delta:Float=1.0, TimeStep:Int=Default_TimeStep)
		'Local VX:Float = (Parent.Velocity.X*((Polygon.Width / 2.0)*TimeStep)*Delta) ' + (Polygon.Width / 2.0)
		'Local VY:Float = (Parent.Velocity.Y*((Polygon.Height / 2.0)*TimeStep)*Delta) ' + (Polygon.Height / 2.0)
		
		Local V:= Parent.Collision_Velocity
		
		Local VX:Float = (V.X*(TimeStep)*Delta) ' + (Polygon.Width / 2.0)
		Local VY:Float = (V.Y*(TimeStep)*Delta) ' + (Polygon.Height / 2.0)
		
		P.X = DotProduct(Axis.X, Axis.Y, Polygon.Points[0]+VX, Polygon.Points[1]+VY); P.Y = P.X
		
		For Local I:= 2 Until Polygon.Points.Length Step 2
			Local Product:= DotProduct(Axis.X, Axis.Y, Polygon.Points[I]+VX, Polygon.Points[I+1]+VY)
			
			If (Product < P.X) Then
				P.X = Product
			Elseif (Product > P.Y) Then
				P.Y = Product
			Endif
		Next
		
		#Rem
		'P.X = Axis.DotProduct(Points[0]); P.Y = P.X
		
		'TimeStep = 1 ' 4 ' 1 ' 2
		
		Local VX:Float = Abs(Parent.Velocity.X * TimeStep)
		Local VY:Float = Abs(Parent.Velocity.Y * TimeStep)
		
		Local Center:= Polygon.Center()
		
		Local XDelta:Float = (Sgn(Polygon.Points[0] - Center.X)*VX)
		Local YDelta:Float = (Sgn(Polygon.Points[1] - Center.Y)*VY)
		
		'Polygon.Points[0].X = Polygon.Points[0].X+XDelta
		'Polygon.Points[0].Y = Polygon.Points[0].Y+YDelta
		
		Local XDist:Float = 0.0
		Local YDist:Float = 0.0
		
		Local TP_MAX_X:= TargetPolygon.MaximumX
		Local TP_MAX_Y:= TargetPolygon.MaximumY
		
		Local TP_MIN_X:= TargetPolygon.MinimumX
		Local TP_MIN_Y:= TargetPolygon.MinimumY
		
		' Calculate the X and Y distances:
		If (Polygon.Points[0] > TP_MAX_X) Then
			XDist = Abs(Polygon.Points[0] - TP_MAX_X)
		Elseif (Polygon.Points[0] < TP_MIN_X) Then
			XDist = Abs(Polygon.Points[0] - TP_MIN_X)
		Endif
		
		' Calculate the X and Y distances:
		If (Polygon.Points[1] > TP_MAX_Y) Then
			YDist = Abs(Polygon.Points[1] - TP_MAX_Y)
		Elseif (Polygon.Points[1] < TP_MIN_Y) Then
			YDist = Abs(Polygon.Points[1] - TP_MIN_Y)
		Endif
		
		Local PX:= Clamp(Polygon.Points[0]+XDelta, Polygon.Points[0]-XDist, Polygon.Points[0]+XDist)
		Local PY:= Clamp(Polygon.Points[1]+YDelta, Polygon.Points[1]-YDist, Polygon.Points[1]+YDist)
		
		'Print("PX: " + Polygon.Points[0]+XDelta)
		
		'Polygon.Points[0] = PX
		'Polygon.Points[1] = PY
		
		P.X = DotProduct(Axis.X, Axis.Y, PX, PY); P.Y = P.X
		
		For Local I:= 2 Until Polygon.Points.Length Step 2
			' Local variable(s):
			'Local Product:Float = Axis.DotProduct(Points[I])
			
			Local XDist:Float = 0.0
			Local YDist:Float = 0.0
			
			Local XDelta:Float = (Sgn(Polygon.Points[I] - Center.X)*VX)
			Local YDelta:Float = (Sgn(Polygon.Points[I+1] - Center.Y)*VY)
			
			' Calculate the X and Y distances:
			If (Polygon.Points[I] > TP_MAX_X) Then
				XDist = Abs(Polygon.Points[I] - TP_MAX_X)
			Elseif (Polygon.Points[I] < TP_MIN_X) Then
				XDist = Abs(Polygon.Points[I] - TP_MIN_X)
			Endif
			
			' Calculate the X and Y distances:
			If (Polygon.Points[I+1] > TP_MAX_Y) Then
				YDist = Abs(Polygon.Points[I+1] - TP_MAX_Y)
			Elseif (Polygon.Points[I+1] < TP_MIN_Y) Then
				YDist = Abs(Polygon.Points[I+1] - TP_MIN_Y)
			Endif
			
			'Polygon.Points[I].X = Polygon.Points[I].X+XDelta
			'Polygon.Points[I].Y = Polygon.Points[I].Y+YDelta
			
			Local PX:= Clamp(Polygon.Points[I]+XDelta, Polygon.Points[I]-XDist, Polygon.Points[I]+XDist)
			Local PY:= Clamp(Polygon.Points[I+1]+YDelta, Polygon.Points[I+1]-YDist, Polygon.Points[I+1]+YDist)
			
			'Polygon.Points[I] = PX
			'Polygon.Points[I+1] = PY
			
			'Local Product:= DotProduct(Axis.X, Axis.Y, Polygon.Points[I]+XDelta, Polygon.Points[I+1]+YDelta)
			Local Product:= DotProduct(Axis.X, Axis.Y, PX, PY)
			
			If (Product < P.X) Then
				P.X = Product
			Elseif (Product > P.Y) Then
				P.Y = Product
			Endif
		Next
		#End
		
		Return
	End
	
	' This checks for a 1D range overlap.
	Method ProjectionOverlap:Bool(P1:Vector2D<Float>, P2:Vector2D<Float>)
		Return (P1.Y > P2.X And P1.X < P2.Y)
	End
	
	' Allocation / Deallocation related:
	
	' This generates a new vector object from the internal pool, copying from the input.
	Method CopyVector:Vector2D<Float>(X:Vector2D<Float>)
		Local V:= AllocateRawVector()
		
		V.Assign(X)
		
		Return V
	End
	
	' This will allocate a vector from the internal pool with all elements set to zero.
	Method AllocateVector:Vector2D<Float>()
		Local V:= AllocateRawVector()
		
		V.Zero()
		
		Return V
	End
	
	' This will allocate a vector using the values specified.
	Method AllocateVector:Vector2D<Float>(X:Float, Y:Float)
		Local V:= AllocateRawVector()
		
		V.X = X
		V.Y = Y
		
		Return V
	End
	
	' This command allocates a vector from the internal pool.
	' When using this command, or any related allocation commands,
	' please call 'DeallocateVector' when you're finished with it.
	' This does not guarantee a "zeroed vector".
	Method AllocateRawVector:Vector2D<Float>()
		Return VectorPool.Allocate()
	End
	
	' This will "deallocate" the vector specified.
	' After a vector has been accepted back into the internal pool,
	' its state will be undefined until allocated at another time.
	' All other code which references 'X' will be considered to have undefined behavior.
	Method DeallocateVector:Void(X:Vector2D<Float>)
		VectorPool.Free(X)
		
		Return
	End
	
	Method AllocateCollisionResponse:CollisionInfo()
		Return ResponsePool.Allocate()
	End
	
	Method DeallocateCollisionResponse:Void(X:CollisionInfo)
		ResponsePool.Free(X.Free())
		
		Return
	End
	
	' Deallocation macros:
	Method Deallocate:Void(X:Vector2D<Float>)
		DeallocateVector(X)
		
		Return
	End
	
	Method Deallocate:Void(C:CollisionInfo)
		DeallocateCollisionResponse(C)
		
		Return
	End
	
	' Methods (Protected):
	Protected
	
	' Collision-data related:
	
	' This will map the axes of 'P' to the current collision-context.
	Method MapAxes:Void(P:Polygon)
		AdjustCollisionData(P.Points.Length/2)
		MapAxesToContext(P)
		
		Return
	End
	
	' Mutate the current collision-state into containing the axes of 'P'.
	Method MapAxesToContext:Void(P:Polygon)
		For Local I:= 0 Until P.Points.Length Step 2
			' Local variable(s):
			Local CollisionAxis:= CollisionAxes.Get(I/2) ' RawAxes[I]
			
			Local P2_X:Float, P2_Y:Float
			
			'CollisionAxis.Zero()
			
			If (I >= (P.Points.Length - 2)) Then
				P2_X = P.Points[0]
				P2_Y = P.Points[1]
			Else
				P2_X = P.Points[I+2]
				P2_Y = P.Points[I+3]
			Endif
			
			Polygon.Edge(P.Points[I], P.Points[I+1], P2_X, P2_Y, CollisionAxis)
		Next
		
		Return
	End
	
	' This will automatically manage allocation and deallocation
	' of vectors for the 'CollisionAxes' container.
	Method AdjustCollisionData:Void(Size:Int)
		Local CAL:= CollisionAxes.Length
		
		If (Size > CAL) Then
			For Local I:= 1 To (Size-CAL)
				'CollisionAxes.Push(AllocateVector())
				
				CollisionAxes.Push(AllocateRawVector())
			Next
		Elseif (Size < CAL) Then
			For Local I:= 1 To (CAL-Size)
				Deallocate(CollisionAxes.Pop())
			Next
		Endif
		
		Return
	End
	
	' This will deallocate all vectors in the 'CollisionAxes' container.
	' Once the vectors are deallocated, this will then clear the container properly.
	Method DeallocateCollisionData:Void()
		' Check for errors:
		If (CollisionAxes.IsEmpty()) Then
			Return
		Endif
		
		' Deallocate every axis:
		For Local A:= Eachin CollisionAxes
			Deallocate(A)
		Next
		
		' Clear all ties to the undefined references.
		CollisionAxes.Clear()
		
		Return
	End
	
	Public
	
	' Properties (Public):
	' Nothing so far.
	
	' Properties (Protected):
	Protected
	
	#Rem
	Method RawAxes:Vector2D<Float>[]() Property
		Return CollisionAxes.Data()
	End
	#End
	
	Public
	
	' Fields (Public):
	' Nothing so far.
	
	' Fields (Private):
	Private
	
	' A pool of vectors, used for calculation.
	Field VectorPool:Pool<Vector2D<Float>>
	
	' The axes used for convex collision checking.
	Field CollisionAxes:Stack<Vector2D<Float>>
	
	' A pool of collision-information response objects.
	Field ResponsePool:Pool<CollisionInfo>
	
	Public
End