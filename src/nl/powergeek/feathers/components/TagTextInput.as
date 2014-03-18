package nl.powergeek.feathers.components
{
	import feathers.controls.Button;
	import feathers.controls.LayoutGroup;
	import feathers.controls.TextInput;
	import feathers.core.FeathersControl;
	import feathers.events.FeathersEventType;
	import feathers.layout.AnchorLayout;
	import feathers.layout.AnchorLayoutData;
	import feathers.layout.HorizontalLayout;
	
	import flash.ui.Keyboard;
	
	import nl.powergeek.feathers.themes.PinboredMobileTheme;
	
	import org.osflash.signals.Signal;
	
	import starling.display.DisplayObject;
	import starling.display.Quad;
	import starling.display.Sprite;
	import starling.events.Event;
	import starling.events.KeyboardEvent;
	
	public class TagTextInput extends FeathersControl
	{
		public static const
			MAX_TAGS:Number = 3;
		
		private var
			_tagCount:Number = 0,
			_tags:LayoutGroup = new LayoutGroup(),
			_componentLayoutGroup:LayoutGroup = new LayoutGroup(),
			_textInput:TextInput = new TextInput(),
			_backgroundFactory:Function = defaultBackgroundFactory,
			_tagFactory:Function = defaultTagFactory,
			_background:DisplayObject,
			_separatorFactory:Function = defaultSeparatorFactory,
			separatorTop:DisplayObject,
			separatorBottom:DisplayObject,
			_searchButton:Button,
			_screenDPIscale:Number,
			_padding:Number = 10,
			_tagNames:Vector.<String> = new Vector.<String>;
		
		public const
			searchTagsTriggered:Signal = new Signal(Vector.<String>);
		
		public static const
			TAG_HEIGHT:uint = 28,
			SEARCHBUTTON_HEIGHT:uint = TAG_HEIGHT + 6;

		public function TagTextInput(screenDPIscale:Number)
		{
			super();
			this._screenDPIscale = screenDPIscale;
		}
		
		override protected function initialize():void 
		{
			super.initialize();
			
			// first create background
			this._background = _backgroundFactory();
			this.addChild(this._background);
			
			// create separators
			separatorTop = _separatorFactory();
			separatorBottom = _separatorFactory();
			this.addChild(separatorTop);
			this.addChild(separatorBottom);
			
			// add component layout
			var componentLayoutData:AnchorLayout = new AnchorLayout();
			_componentLayoutGroup.layout = componentLayoutData;
			this.addChild(this._componentLayoutGroup);
			
			// create tags layoutgroup
			var tagLayout:HorizontalLayout = new HorizontalLayout();
			tagLayout.padding = this._padding;
			tagLayout.gap = this._padding;
			tagLayout.horizontalAlign = HorizontalLayout.HORIZONTAL_ALIGN_LEFT;
			tagLayout.verticalAlign = HorizontalLayout.VERTICAL_ALIGN_JUSTIFY;
			
			// assign layout type and add the tags layoutGroup
			_tags.layout = tagLayout;
			
			// create and add textinput
			this._textInput.prompt = "add tags for filtering";
			this._textInput.nameList.add(PinboredMobileTheme.TEXTINPUT_TRANSPARENT_BACKGROUND);
//			this._textInput.height = TAG_HEIGHT;
//			this._textInput.padding = 0;
//			this._textInput.width = 200;
			
			// add listeners
			this._textInput.addEventListener(Event.CHANGE, textInputHandler);
			this.addEventListener(KeyboardEvent.KEY_DOWN, keyInputHandler);
			this._tags.addChild(this._textInput);
			
			// add tag layout group
			this._componentLayoutGroup.addChild(_tags);
			this._tags.validate();
			
			// create searchbutton
			_searchButton = new Button();
			_searchButton.label = 'search & filter';
			_searchButton.height = SEARCHBUTTON_HEIGHT;
			_searchButton.nameList.add(PinboredMobileTheme.BUTTON_QUAD_CONTEXT_PRIMARY);
			_searchButton.addEventListener(Event.TRIGGERED, searchButtonTriggeredHandler); 
				
			var buttonLayoutData:AnchorLayoutData = new AnchorLayoutData();
			buttonLayoutData.verticalCenter = 0;
			buttonLayoutData.right = this._padding * 2;
			_searchButton.layoutData = buttonLayoutData;
			this._componentLayoutGroup.addChild(this._searchButton);
		}
		
		private function searchButtonTriggeredHandler():void
		{
//			if(this._tagNames.length > 0) {
			searchTagsTriggered.dispatch(this._tagNames);
//			}
		}
		
		private function keyInputHandler(event:KeyboardEvent):void
		{
			if(event.keyCode == Keyboard.BACKSPACE) {
				trace('backspace pressed!');
				if(_textInput.text.length == 0) {
					trace('TODO remove previous tag here.');
				}
			}
		}
		
		private function textInputHandler(event:Event):void
		{
			// get TextInput
			var textInput:TextInput = TextInput(event.target);
			var text:String = textInput.text;
			
			// if text contains space or comma
			var spaceIndex:Number = text.indexOf(' ');
			var commaIndex:Number = text.indexOf(', ');
			
			// if we do not yet have reached the max. number of tags
			if(this._tagCount < MAX_TAGS) {
				
				if(spaceIndex > -1 || commaIndex > -1) {
					
					// remove the word from this text input
					var tagText:String = '';
					
					if(spaceIndex > -1) {
						tagText = text.substr(0, spaceIndex);
					} else if(commaIndex > -1) {
						tagText = text.substr(0, commaIndex);
					}
					
					// create the tag and add it to the list o tags
					var tag:Tag = _tagFactory(tagText);
					
					// add listener to tag removed signal
					tag.removed.addOnce(function():void {
						_tags.removeChild(tag);
						// decrement tagCount
						_tagCount--;
						// remove from tagNames
						_tagNames.splice(_tagNames.indexOf(tag.text), 1);
						// update shit
						invalidate(FeathersControl.INVALIDATION_FLAG_ALL);
					});
					
					// quickly remove the textInput, then add the tag, then re-add the textInput!
					_tags.removeChild(this._textInput);
					_tags.addChild(tag);
					_tags.addChild(this._textInput);
					
					// add tag text to tagText array for quick access
					_tagNames.push(tag.text);
					
					// set focus back to textinput after removing and adding it to display list
					_textInput.setFocus();
					
					// clear the text
					textInput.text = '';
					
					// increment tagCount
					_tagCount++;
					
					// and invalidate, need to redraw this thing
					invalidate(FeathersControl.INVALIDATION_FLAG_ALL);
				}
			}
		}
		
		override protected function draw():void
		{
			// phase 1 commit
			_tags.validate();
			
			// enable or disable tag input
			if(this._tagCount < MAX_TAGS) {
				this._textInput.isEnabled = true;
			} else {
				// disable tag input
				this._textInput.text = '';
				this._textInput.isEnabled = false;
			}
			this._textInput.validate();
			
			// phase 2 measurements
			_componentLayoutGroup.width = this.width;
			_componentLayoutGroup.height = this._tags.height;
			
			_background.width = _componentLayoutGroup.width;
			_background.height = _componentLayoutGroup.height;
			
			// resize textinput to remaining width between tags and search button
			this._textInput.width = _componentLayoutGroup.width - (_tags.width - _textInput.width) - _searchButton.width;
			
			// separators need to be on top and bottom
			separatorTop.y = this.y;
			separatorTop.width = _background.width;
			
			// content in between
			_componentLayoutGroup.y = separatorTop.y + separatorTop.height;
			_background.y = _componentLayoutGroup.y;
			
			// and bottom separator at the bottom
			separatorBottom.y = _componentLayoutGroup.y + _componentLayoutGroup.height;
			separatorBottom.width = _background.width;
			
			this.width = Math.max(this.actualWidth, this.width);
			this.height = this.separatorTop.height + this._componentLayoutGroup.height + this.separatorBottom.height;
			
			// phase 3 layout
			_searchButton.validate();
			
		}
		
		private function defaultTagFactory(text:String):Tag
		{
			return new Tag(_screenDPIscale, text);
		}
		
		public function get tagFactory():Function
		{
			return _tagFactory;
		}

		public function set tagFactory(value:Function):void
		{
			_tagFactory = value;
		}
		
		private function defaultBackgroundFactory():DisplayObject
		{
//			return new Quad(100, 100, 0x464646);
			
			var bg:Quad = new Quad(10, 10, 0x000000);
			bg.alpha = 0.2;
			return bg;
		}
		
		public function get backgroundFactory():Function
		{
			return _backgroundFactory;
		}

		public function set backgroundFactory(value:Function):void
		{
			_backgroundFactory = value;
		}
		
		private function defaultSeparatorFactory():DisplayObject
		{
			var line:Quad = new Quad(5, 5, 0x000000);
			line.alpha = 0.5;
			return line;
		}

		public function get separatorFactory():Function
		{
			return _separatorFactory;
		}

		public function set separatorFactory(value:Function):void
		{
			_separatorFactory = value;
		}


	}
}