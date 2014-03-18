package screens
{
	import feathers.controls.Button;
	import feathers.controls.Callout;
	import feathers.controls.Header;
	import feathers.controls.Label;
	import feathers.controls.LayoutGroup;
	import feathers.controls.List;
	import feathers.controls.Panel;
	import feathers.controls.Screen;
	import feathers.controls.ScrollContainer;
	import feathers.controls.TextInput;
	import feathers.controls.renderers.BaseDefaultItemRenderer;
	import feathers.controls.renderers.IListItemRenderer;
	import feathers.data.ListCollection;
	import feathers.events.FeathersEventType;
	import feathers.layout.VerticalLayout;
	
	import flash.events.Event;
	import flash.net.URLRequest;
	import flash.net.URLVariables;
	
	import nl.powergeek.REST.RESTClient;
	import nl.powergeek.REST.RESTRequest;
	import nl.powergeek.feathers.components.PinboardLayoutGroupItemRenderer;
	import nl.powergeek.feathers.components.Tag;
	import nl.powergeek.feathers.components.TagTextInput;
	import nl.powergeek.feathers.themes.PinboredMobileTheme;
	import nl.powergeek.utils.ArrayCollectionPager;
	
	import org.osflash.signals.ISignal;
	import org.osflash.signals.Signal;
	
	import services.PinboardService;
	
	import starling.display.DisplayObject;
	import starling.display.Image;
	import starling.display.Quad;
	import starling.events.Event;
	import starling.events.ResizeEvent;
	import starling.textures.Texture;
	
	public class ListScreen extends Screen
	{
		[Embed(source="assets/images/pinbored/pinbored-background.jpg")]
		public static const BACKGROUND:Class;
		
		// GUI related
		private var 
			panel:Panel = new Panel(),
			screenGroup:LayoutGroup,
			listScrollContainer:ScrollContainer,
			searchBookmarks:TextInput,
			searchTags:TagTextInput,
			list:List = new List(),
			button:Button,
			_backgroundImage:Image = new Image(Texture.fromBitmap(new BACKGROUND(), false)),
			_panelExcludedSpace:uint = 0;
		
		// REST related
		private var
			restClient:RESTClient,
			resultsPerPage:Number = 25;
		
		// signals
		private var 
			_onLoginScreenRequest:Signal = new Signal( ListScreen );
		
		public function ListScreen()
		{
			super();
			
			// create REST client
			restClient = new RESTClient(
				'https://api.pinboard.in/v1/', 
				'?auth_token=', 
				'michahell:bc82053a1f923175fab7',
				'&format=',
				'json'
			);
		}
		
		override protected function initialize():void
		{
			// create GUI
			createGUI();
			
			// listen for transition complete
			owner.addEventListener(FeathersEventType.TRANSITION_COMPLETE, onTransitionComplete);
		}
		
		private function onTransitionComplete(event:starling.events.Event):void
		{
			// remove listener
			owner.removeEventListener(FeathersEventType.TRANSITION_COMPLETE, onTransitionComplete);
			
			// get all bookmarks and populate list control
			getInitialData();
		}
		
		private function getInitialData():void
		{
			// when searched for tags, update the bookmarks list
			searchTags.searchTagsTriggered.add(function(tagNames:Vector.<String>):void {
				
				AppModel.rawBookmarkDataListFiltered = PinboardService.filterTags(AppModel.rawBookmarkDataList, tagNames);
				trace('done filtering: ' + AppModel.rawBookmarkDataListFiltered.length);
				
				if(AppModel.rawBookmarkDataListFiltered.length > 0) {
					// first, page raw bookmark results (this list can be huge)
					AppModel.rawBookmarkListCollectionPager = new ArrayCollectionPager(AppModel.rawBookmarkDataListFiltered, resultsPerPage);
					var firstResultPageCollection:Array = AppModel.rawBookmarkListCollectionPager.first();
					
					AppModel.bookmarksList = PinboardService.mapRawBookmarksToBookmarks(firstResultPageCollection);
					
					list.dataProvider = null;
					list.dataProvider = new ListCollection(AppModel.bookmarksList);
				} else {
					trace('no results after filtering...');
					list.dataProvider = null;
				}
				
			});
			
			// throw all bookmarks into a list
			PinboardService.allBookmarksReceived.add(function(event:flash.events.Event):void {
				
				var parsedResponse:Object = JSON.parse(event.target.data as String);
				
				parsedResponse.forEach(function(bookmark:Object, index:int, array:Array):void {
					AppModel.rawBookmarkDataList.push(bookmark);
				});
				
				// first, page raw bookmark results (this list can be huge)
				AppModel.rawBookmarkListCollectionPager = new ArrayCollectionPager(AppModel.rawBookmarkDataList, resultsPerPage);
				var firstResultPageCollection:Array = AppModel.rawBookmarkListCollectionPager.first();
				
				AppModel.bookmarksList = PinboardService.mapRawBookmarksToBookmarks(firstResultPageCollection);
				
				//				list.dataProvider = null;
				list.dataProvider = new ListCollection(AppModel.bookmarksList);
			});
			
			// get all bookmarks
			// PinboardService.GetAllBookmarks();
			PinboardService.GetAllBookmarks(new Vector.<String>(['programming', 'A.I.']));
		}
		
		private function createGUI():void
		{
			// create nice background
			this.addChild(_backgroundImage);
			
			// add a panel with a header, footer and no scroll shit
			this.panel.verticalScrollPolicy = Panel.SCROLL_POLICY_OFF;
			this.panel.horizontalScrollPolicy = Panel.SCROLL_POLICY_OFF;
			this.panel.nameList.add(PinboredMobileTheme.PANEL_TRANSPARENT_BACKGROUND);
			
			this.panel.headerFactory = function():Header
			{
				const header:Header = new Header();
				header.title = "Bookmarks list";
				header.titleAlign = Header.TITLE_ALIGN_PREFER_LEFT;
				
				if(!this.searchBookmarks)
				{
					this.searchBookmarks = new TextInput();
					this.searchBookmarks.width = 400;
					this.searchBookmarks.prompt = "search keyword";
					
					//we can't get an enter key event without changing the returnKeyLabel
					//not using ReturnKeyLabel.GO here so that it will build for web
					this.searchBookmarks.textEditorProperties.returnKeyLabel = "go";
					
					this.searchBookmarks.addEventListener(FeathersEventType.ENTER, input_enterHandler);
				}
				
				header.rightItems = new <DisplayObject>[this.searchBookmarks];
				_panelExcludedSpace += header.height;
				
				return header;
			}
			
			this.panel.footerFactory = function():ScrollContainer
			{
				var container:ScrollContainer = new ScrollContainer();
				container.nameList.add( ScrollContainer.ALTERNATE_NAME_TOOLBAR );
				container.horizontalScrollPolicy = ScrollContainer.SCROLL_POLICY_OFF;
				container.verticalScrollPolicy = ScrollContainer.SCROLL_POLICY_OFF;
				_panelExcludedSpace += container.height;
				return container;
			}
			
			this.panel.padding = 0;
			this.addChild(panel);
				
			// create screen layout (vertical unit)
			var panelLayout:VerticalLayout = new VerticalLayout();
			panelLayout.gap = 0;
			panelLayout.padding = 0;
			this.panel.layout = panelLayout;
			
			// add the tag search 'bar'
			this.searchTags = new TagTextInput(this._dpiScale);
			this.searchTags.width = this.width;
			this.panel.addChild(this.searchTags);
			
			// add a scrollcontainer for the list
			this.listScrollContainer = new ScrollContainer();
			this.listScrollContainer.verticalScrollPolicy = ScrollContainer.SCROLL_POLICY_ON;
			
			// update scrollcontainer height
			this.listScrollContainer.height = panel.height - _panelExcludedSpace - searchTags.height - 100;
			
			this.panel.addChild(this.listScrollContainer);
				
			// add a list for the bookmarks
			list.itemRendererFactory = function():IListItemRenderer
			{
				var renderer:PinboardLayoutGroupItemRenderer = new PinboardLayoutGroupItemRenderer();
				renderer.padding = 5;
				return renderer;
			};
			
			list.itemRendererProperties.horizontalAlign = Button.HORIZONTAL_ALIGN_LEFT;
			list.itemRendererProperties.verticalAlign = Button.VERTICAL_ALIGN_MIDDLE;
			list.itemRendererProperties.iconPosition = Button.ICON_POSITION_LEFT;
			list.itemRendererProperties.gap = 10;
			list.isSelectable = false;
			
			// add list to panel
			this.listScrollContainer.addChild(list);
			var listBg:Quad = new Quad(50, 50, 0x000000);
			listBg.alpha = 0.3;
			this.list.backgroundSkin = this.list.backgroundDisabledSkin = listBg;
		}
		
		private function input_enterHandler():void
		{
			trace('entered search key word');
		}
		
		override protected function draw():void
		{
			// commit 
			
			// measurement
			panel.width = AppModel.starling.stage.stageWidth;
			panel.height = AppModel.starling.stage.stageHeight;
			
			_backgroundImage.width = this.width;
			_backgroundImage.height = this.height;
			
			// update screengroup, searchtags, scrollcontainer, list width etc.
			list.width = panel.width;
			listScrollContainer.width = panel.width;
			searchTags.width = panel.width;
			
			// update scrollcontainer height
			this.listScrollContainer.height = panel.height - _panelExcludedSpace - searchTags.height - 100;
			
			// layout
		}

		public function get onLoginScreenRequest():ISignal
		{
			return _onLoginScreenRequest;
		}

	}
}